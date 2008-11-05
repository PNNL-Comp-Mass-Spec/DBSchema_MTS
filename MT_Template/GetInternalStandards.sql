/****** Object:  StoredProcedure [dbo].[GetInternalStandards] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.GetInternalStandards
/****************************************************	
**  Desc: Returns Internal Standards for the given job
**		  or for the internal standard(s) specified by @InternalStdExplicit
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: none
**
**  Auth:	mem
**	Date:	12/20/2005
**			06/22/2006 mem - Now posting an error if the internal standard name is unknown
**
****************************************************/
(
	@Job int = 0,									-- Set to a non-zero value to allow auto-selection of internal standards from this job; if @InternalStdExplicit is not blank, then both the job's internal standard(s) and that given by @InternalStdExplicit will be used
	@InternalStdExplicit varchar(255) = '',			-- Specifies the name of the internal std to include (regardless of @Job); can be a comma-separated list of internal standards
	@InternalStdListUsed varchar(255) = '' OUTPUT	-- List of internal standards used
)
As
	Set NoCount On

	Declare @myRowCount int	
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Declare @PreDigestIntStd varchar(50),
			@PostDigestIntStd varchar(50),
			@DatasetIntStd varchar(50)
	Set @PreDigestIntStd = ''
	Set @PostDigestIntStd = ''
	Set @DatasetIntStd = ''

	Declare @message varchar(255)

	Declare @SeqID int
	Declare @InternalStdMixCount int
	Declare @SeqCountAdded int
	Declare @Continue tinyint
	
	Declare @InternalStdComponents int
	Set @InternalStdComponents = 0
	
	Declare @UndefinedInternalStdList varchar(512)
	Set @UndefinedInternalStdList = ''
	
	---------------------------------------------------	
	-- Validate the input parameters
	---------------------------------------------------	
	Set @Job = IsNull(@Job, 0)
	Set @InternalStdExplicit = IsNull(@InternalStdExplicit, '')

	Set @InternalStdListUsed = ''

	---------------------------------------------------	
	-- Create a temporary table to hold the list of Seq_ID values
	--  that belong to the internal standards specified
	-- This table also holds the mass, NET, and other stats for the internal standards
	---------------------------------------------------	
	CREATE TABLE #TmpSeqsForInternalStds (
		Seq_ID int NOT NULL,
		IsDefined tinyint NOT NULL,
		Description varchar(255) NULL ,
		Peptide varchar(850) NULL ,
		Monoisotopic_Mass float NOT NULL ,
		Avg_NET real NOT NULL ,
		Charge_Minimum int NULL ,
		Charge_Maximum int NULL ,
		Charge_Highest_Abu int NULL 
	)

	CREATE CLUSTERED INDEX #IX_TmpSeqsForInternalStds ON #TmpSeqsForInternalStds (Seq_ID ASC)

	---------------------------------------------------	
	-- Create a temporary table to hold the internal standards to include
	---------------------------------------------------	
	CREATE TABLE #TmpInternalStdMixes (
		Internal_Std_Name varchar(512)
	)
	

	---------------------------------------------------	
	-- Parse @InternalStdExplicit, splitting on @valueDelimiter
	---------------------------------------------------	
	Declare @ListRemaining varchar(255)
	Declare @CurrValue varchar(255)
	Declare @DelimiterLoc int
	
	Declare @valueDelimiter char(1)
	Set @valueDelimiter = ','
	
	Set @ListRemaining = @InternalStdExplicit
	While Len(@ListRemaining) > 0
	Begin
		Set @DelimiterLoc = CharIndex(@valueDelimiter, @ListRemaining)		
		If @DelimiterLoc > 0
		 Begin
			Set @CurrValue = RTrim(LTrim(SubString(@ListRemaining, 1, @DelimiterLoc-1)))
			Set @ListRemaining = RTrim(LTrim(SubString(@ListRemaining, @DelimiterLoc+1, Len(@ListRemaining)-@DelimiterLoc)))
		 End
		Else			--last inclusion item
		 Begin
			Set @CurrValue = RTrim(LTrim(@ListRemaining))
			Set @ListRemaining = ''
		 End

		If Len(@CurrValue) > 0
			INSERT INTO #TmpInternalStdMixes (Internal_Std_Name)
			VALUES (@CurrValue)
	End


	---------------------------------------------------	
	-- If @Job is non-zero, then lookup the details in T_FTICR_Analysis_Description
	---------------------------------------------------	
	If @Job <> 0
	Begin
		-- Lookup the internal standard(s) for the dataset
		-- If @InternalStdExplicit contained any entries, then the dataset's internal standard(s)
		--  will be appended to #TmpInternalStdMixes
		SELECT 	@PreDigestIntStd = PreDigest_Internal_Std,
				@PostDigestIntStd = PostDigest_Internal_Std,
				@DatasetIntStd = Dataset_Internal_Std
		FROM T_FTICR_Analysis_Description
		WHERE Job = @Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount > 0
		Begin
			If Len(@PreDigestIntStd) > 0
				INSERT INTO #TmpInternalStdMixes (Internal_Std_Name)
				VALUES (@PreDigestIntStd)
			
			If Len(@PostDigestIntStd) > 0
				INSERT INTO #TmpInternalStdMixes (Internal_Std_Name)
				VALUES (@PostDigestIntStd)

			If Len(@DatasetIntStd) > 0
				INSERT INTO #TmpInternalStdMixes (Internal_Std_Name)
				VALUES (@DatasetIntStd)
		End
	End
	

	---------------------------------------------------
	-- Populate #TmpSeqsForInternalStds with the Internal Standard peptides 
	---------------------------------------------------
	--
	Set @InternalStdMixCount = 0
	SELECT @InternalStdMixCount = COUNT(*)
	FROM #TmpInternalStdMixes
	
	If @InternalStdMixCount > 0
	Begin -- <a>
	
		-- Construct a comma-separated list of the internal standard mixes in #TmpInternalStdMixes
		--
		Set @InternalStdListUsed = ''
		SELECT @InternalStdListUsed = @InternalStdListUsed + Internal_Std_Name + ', '
		FROM (	SELECT DISTINCT Internal_Std_Name
				FROM #TmpInternalStdMixes IntStdMixes INNER JOIN 
					 MT_Main.dbo.T_Internal_Standards IntStd ON IntStd.Name = IntStdMixes.Internal_Std_Name INNER JOIN
					 MT_Main.dbo.T_Internal_Std_Composition ISComposition ON ISComposition.Internal_Std_Mix_ID = IntStd.Internal_Std_Mix_ID
			 ) LookupQ
		ORDER BY Internal_Std_Name
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If Len(@InternalStdListUsed) > 2
			Set @InternalStdListUsed = Left(RTrim(@InternalStdListUsed), Len(RTrim(@InternalStdListUsed))-1)

		-- Validate that each entry in #TmpInternalStdMixes is defined in MT_Main
		--
		Set @UndefinedInternalStdList = ''
		SELECT @UndefinedInternalStdList = @UndefinedInternalStdList + Internal_Std_Name + ', '
		FROM (	SELECT DISTINCT IntStdMixes.Internal_Std_Name AS Internal_Std_Name
				FROM #TmpInternalStdMixes IntStdMixes LEFT OUTER JOIN
					 MT_Main.dbo.T_Internal_Standards IntStd ON IntStd.Name = IntStdMixes.Internal_Std_Name
				WHERE IntStd.Internal_Std_Mix_ID IS NULL
			 ) LookupQ
		ORDER BY Internal_Std_Name
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount > 0
		Begin
			If Len(@UndefinedInternalStdList) > 2
				Set @UndefinedInternalStdList = Left(RTrim(@UndefinedInternalStdList), Len(RTrim(@UndefinedInternalStdList))-1)
			
			Set @message = 'Unknown internal standard mix name requested: ' + @UndefinedInternalStdList
			Execute PostLogEntry 'Error', @message, 'GetInternalStandards', 1
			Set @message = ''
		End
		

		-- Populate #TmpSeqsForInternalStds using the tables in MT_Main
		--
		INSERT INTO #TmpSeqsForInternalStds (Seq_ID, IsDefined, Description, Peptide, 
											 Monoisotopic_Mass, Avg_NET, 
											 Charge_Minimum, Charge_Maximum, Charge_Highest_Abu)
		SELECT	ISC.Seq_ID, 0 As IsDefined, ISC.Description, ISC.Peptide, 
				ISC.Monoisotopic_Mass, ISC.Avg_NET, 
				ISC.Charge_Minimum, ISC.Charge_Maximum, ISC.Charge_Highest_Abu
		FROM (	SELECT DISTINCT ISC.Seq_ID
				FROM #TmpInternalStdMixes IntStdMixes INNER JOIN
					 MT_Main.dbo.T_Internal_Standards IntStd ON IntStdMixes.Internal_Std_Name = IntStd.Name INNER JOIN
					 MT_Main.dbo.T_Internal_Std_Composition ISComposition ON IntStd.Internal_Std_Mix_ID = ISComposition.Internal_Std_Mix_ID INNER JOIN
					 MT_Main.dbo.T_Internal_Std_Components ISC ON ISComposition.Seq_ID = ISC.Seq_ID
			 ) LookupQ INNER JOIN MT_Main.dbo.T_Internal_Std_Components ISC ON LookupQ.Seq_ID = ISC.Seq_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		Set @InternalStdComponents = @myRowCount
		--
		If @MyError <> 0
			Goto Done
			
		If @InternalStdComponents > 0
		Begin -- <b>
			-- Need to validate that each entry in #TmpSeqsForInternalStds is present in T_Mass_Tags
			-- First, mark the entries in #TmpSeqsForInternalStds that are present in T_Mass_Tags
			
			UPDATE #TmpSeqsForInternalStds
			SET IsDefined = 1
			FROM #TmpSeqsForInternalStds INNER JOIN
				 T_Mass_Tags MT ON #TmpSeqsForInternalStds.Seq_ID = MT.Mass_Tag_ID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			If @myRowCount < @InternalStdComponents
			Begin -- <c>
				-- One or more entries in #TmpSeqsForInternalStds is not defined in T_Mass_Tags
				-- Loop through #TmpSeqsForInternalStds and add each missing entry
				
				Set @SeqID = 0
				SELECT @SeqID = MIN(Seq_ID)-1
				FROM #TmpSeqsForInternalStds
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				Set @SeqCountAdded = 0
				Set @Continue = 1
				While @Continue = 1 and @myError = 0
				Begin -- <d>
					-- Grab the next entry
					SELECT TOP 1 @SeqID = Seq_ID
					FROM #TmpSeqsForInternalStds
					WHERE Seq_ID > @SeqID AND IsDefined = 0
					ORDER BY Seq_ID
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
				
					If @myRowCount = 0 or @myError <> 0
						Set @Continue = 0
					Else
					Begin
						exec @myError = AddUpdateInternalStandardEntry @SeqID, @PostLogEntry = 0
						
						If @myError = 0
							Set @SeqCountAdded = @SeqCountAdded + 1
					End
				End -- </d>
				
				If @SeqCountAdded > 0
				Begin
					Set @message = 'Added ' + Convert(varchar(12), @SeqCountAdded) + ' new peptides to T_Mass_Tags for internal standard'
					If @InternalStdMixCount > 1
						Set @message = @message + 's'
					
					Set @message = @message + ' ' + @InternalStdListUsed
					
					Execute PostLogEntry 'Normal', @message, 'GetInternalStandards'
					Set @message = ''
				End

			End -- </c>
		End -- </b>

		If @myError <> 0
		DELETE FROM #TmpSeqsForInternalStds

	End -- </a>


	---------------------------------------------------
	-- For internal standards with Internal_Standard_Only = 0 and
	--  non-null mass and NET values in T_Mass_Tags and _Mass_Tags_NET, 
	--  use the mass and NET from this DB rather than from T_Internal_Std_Components
	---------------------------------------------------
	UPDATE #TmpSeqsForInternalStds
	SET Monoisotopic_Mass = MT.Monoisotopic_Mass,
		Avg_NET = MTN.Avg_GANET
	FROM #TmpSeqsForInternalStds IST INNER JOIN
		 T_Mass_Tags MT ON IST.Seq_ID = MT.Mass_Tag_ID INNER JOIN
		 T_Mass_Tags_NET MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID
	WHERE Internal_Standard_Only = 0 AND 
		  NOT MT.Monoisotopic_Mass IS NULL AND
		  NOT MTN.Avg_GANET IS NULL 
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	
	---------------------------------------------------
	-- Return the details for the internal standard components
	---------------------------------------------------
	--
	SELECT	Seq_ID, 
			Description, 
			Peptide, 
			Monoisotopic_Mass, 
			Avg_NET, 
			Charge_Minimum, 
			Charge_Maximum, 
			Charge_Highest_Abu
	FROM #TmpSeqsForInternalStds
	ORDER BY Monoisotopic_Mass, Seq_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

Done:	
	Return @myError


GO
GRANT EXECUTE ON [dbo].[GetInternalStandards] TO [DMS_SP_User]
GO
GRANT VIEW DEFINITION ON [dbo].[GetInternalStandards] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[GetInternalStandards] TO [MTS_DB_Lite]
GO
