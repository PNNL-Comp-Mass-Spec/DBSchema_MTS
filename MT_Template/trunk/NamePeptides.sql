/****** Object:  StoredProcedure [dbo].[NamePeptides] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.NamePeptides
/****************************************************
** 
**	Desc: 
**		Fills in the columns (Mass_Tag_Name, Cleavage_State,
**			Fragment Number, Fragment_Start, Residue_Start, 
**			Residue_End, Repeat_Count, Terminus_State) in 
**			Mass_Tag_to_Protein_Map
**
**		Return values: 0: success, otherwise, error code
** 
**	Parameters: see below
**		
**	Outputs: @message - description of error if one results,
**					 '' if none
**			 @count - number of rows updated (should be the 
**						same as the number of rows in the table)
** 
**	Auth:	kal
**	Date:	07/15/2003
**			08/23/2003 mem - added RecomputeAll parameter
**			09/19/2004 mem - Changed references to reflect new MTDB schema and added optimization of determining @ProteinLength
**			02/14/2005 mem - Now posting progress messages to the log every 5 minutes
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**			08/10/2006 mem - Now populating Missed_Cleavage_Count
**    
*****************************************************/
(
	@count int = 0 output,						--number of rows updated
	--@cleavageAminoAcids varchar(32) = 'RK-',	--list of amino acids that cleavages occur after
	@message varchar(255) = '' output,
	@AbortOnError int = 0,						--if =0, then go to next Mass_Tag_ID / ref_id pair on error
												--otherwise, return on error
	@namingString varchar(10) = 't',			--string used in naming 'fully cleaved' peptides
	@RecomputeAll tinyint = 0,					-- When 1, recomputes stats for all mass tags; when 0, only computes if the peptide name or peptide cleavage state is null
	@logLevel tinyint = 1
)	
AS
	SET NOCOUNT ON

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @message = ''
	set @count = 0
	
	declare @done int
	declare @LastUniqueRowID int
	declare @UpdateEnabled tinyint
	
	--results extracted for each row are stored in these
	declare @peptide varchar(850)
	declare @Mass_Tag_ID int
	declare @Ref_ID int
	declare @Reference varchar(128)

	set @peptide = ''
	set @Mass_Tag_ID = -1
	set @Ref_ID = -1
	set @Reference = ''
	
	declare @lastProgressUpdate datetime
	Set @lastProgressUpdate = GetDate()
		
	declare @ProteinLength int
	
	--variables for storing calculated results to be output to T_Mass_Tag_to_Protein_Map
	declare @massTagName varchar(255)
	declare @cleavageState tinyint
	declare @fragmentNumber smallint
	declare @fragmentSpan smallint
	declare @residueStart int
	declare @residueEnd int
	declare @repeatCount smallint
	declare @terminusState tinyint
	declare @missedCleavageCount smallint
	

	---------------------------------------------------
	-- Creation of temporary table to pull data from
	---------------------------------------------------
	
	CREATE TABLE #TMPTags (
		[Mass_Tag_ID]	int NOT NULL ,
		[Ref_ID] int NOT NULL,
		[Peptide] varchar (850) NOT NULL,
		[Reference] varchar(128),
		[ProteinLength] int,
		[Unique_Row_ID] int IDENTITY (1, 1) NOT NULL
	)

	CREATE UNIQUE CLUSTERED INDEX #IX_TempTable_TMPTags ON #TMPTags (Unique_Row_ID)

	---------------------------------------------------
	-- copy data to temp table
	---------------------------------------------------
	
	If @RecomputeAll = 0
	  Begin
		INSERT	#TMPTags (
			Mass_Tag_ID, Ref_ID, Peptide, Reference, ProteinLength
			)
		SELECT	MTPM.Mass_Tag_ID,
				MTPM.Ref_ID,
				MT.Peptide,
				PR.Reference,
				IsNull(DataLength(PR.Protein_Sequence), 0)
		FROM	T_Mass_Tag_to_Protein_Map AS MTPM INNER JOIN T_Mass_Tags AS MT ON 
				MTPM.Mass_Tag_ID = MT.Mass_Tag_ID INNER JOIN T_Proteins AS PR ON
				MTPM.Ref_ID = PR.Ref_ID
		WHERE	NOT PR.Protein_Sequence IS NULL AND
				(Mass_Tag_Name IS NULL OR Cleavage_State IS NULL)
		ORDER BY MTPM.Mass_Tag_ID, MTPM.Ref_ID
	  End
	Else
	  Begin
		INSERT	#TMPTags (
			Mass_Tag_ID, Ref_ID, Peptide, Reference, ProteinLength
			)
		SELECT	MTPM.Mass_Tag_ID,
				MTPM.Ref_ID,
				MT.Peptide,
				PR.Reference,
				IsNull(DataLength(PR.Protein_Sequence), 0)
		FROM	T_Mass_Tag_to_Protein_Map AS MTPM INNER JOIN T_Mass_Tags AS MT ON 
				MTPM.Mass_Tag_ID = MT.Mass_Tag_ID INNER JOIN T_Proteins AS PR ON
				MTPM.Ref_ID = PR.Ref_ID
		WHERE	NOT PR.Protein_Sequence IS NULL
		ORDER BY MTPM.Mass_Tag_ID, MTPM.Ref_ID
	  End
	
	
	-- check for errors
	SELECT @myError = @@error, @myRowCount = @@rowcount
	if @myError <> 0 
	begin
		set @message = 'Error while creating data in temporary table'
		goto done
	end
	
	if not(@myRowCount > 0)
	begin
		set @message = 'No rows to compute names for'
		goto done
	end
	
	
	----------------------------------------------
	-- Loop through each row in the temporary table,
	-- calculating the name and other fields
	----------------------------------------------
	Set @done = @myRowCount
	Set @LastUniqueRowID = 0
	
	While @done > 0
	Begin
		-- Select data about one Mass_Tag_ID/ref_id pair from the temporary table
  		SELECT TOP 1 
  			@LastUniqueRowID = Unique_Row_ID,
			@peptide = Peptide, 
			@Mass_Tag_ID = Mass_Tag_ID, 
			@Ref_ID = Ref_ID,
			@Reference = Reference,
			@ProteinLength = ProteinLength
		FROM #TMPTags
		WHERE Unique_Row_ID > @LastUniqueRowID
		ORDER BY Unique_Row_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		set @done = @myRowCount
		if @myError <> 0 
		begin
			set @message = 'Error while reading data from temporary table #TMPTags'
			goto done
		end
		
		If @done = 0
			Set @message = ''
		Else
		Begin		
			------------------------------------------------
			--compute info about peptide
			------------------------------------------------
			--find the start and end indexes of the peptide in the Protein
			EXEC @myError = GetPeptideIndexes 
					@peptide = @peptide, 
					@Ref_ID = @Ref_ID,
					@startIndex = @residueStart output, 
					@endIndex = @residueEnd output,
					@message = @message output
			
			--check for returned error
			if @myError <> 0
			begin
				set @message = 'Error in GetPeptideIndexes: ' + @message
				if @AbortOnError = 0
					goto ErrorCleanup
				else
					goto Done
			end

			-- Determine cleavage state
			EXEC @cleavageState = ComputeCleavageState
					@Ref_ID,
					@residueStart,
					@residueEnd,
					@ProteinLength
			
			set @fragmentNumber = 0
			set @fragmentSpan = 0
				
			If (@cleavageState = 2)  
			Begin
				-- Both ends cleaved, so compute fragment number
				EXEC @fragmentNumber = ComputePeptideFragmentNumber
						@Ref_ID,
						@residueStart,
						@ProteinLength

				-- Compute fragment span
				EXEC @fragmentSpan = ComputeCleavagesInPeptide
						@Ref_ID,
						@residueStart,
						@residueEnd,
						@ProteinLength
			End

			-- Determine the number of missed cleavages
			EXEC @missedCleavageCount = CountMissedCleavagePoints @peptide, @CheckForPrefixAndSuffixResidues = 0

			-- Count the number of times the peptide occurs in the protein sequence	
			EXEC @repeatCount = CountSubstringInProtein @Ref_ID, @peptide
			
			set @terminusState = 0
			if @residueStart = 1
				set @terminusState = 1
			if @residueEnd = @ProteinLength
				set @terminusState = @terminusState + 2
										
			--if fully cleaved, make name like DRAD047.t3.2
			if @cleavageState = 2
				set @massTagName = ltrim(rtrim(@Reference)) + '.' + @namingString
					+ ltrim(rtrim(str(@fragmentNumber)))
					+ '.' + ltrim(rtrim(str(@fragmentSpan)))
					
			--otherwise, use start and end positions, like DRAD047.117.129
			else
				set @massTagName = ltrim(rtrim(@Reference)) + '.' 
					+ ltrim(rtrim(str(@residueStart)))
					+ '.' + ltrim(rtrim(str(@residueEnd)))

			-----------------------------------
			--update mass tag name with computed value where Mass_Tag_ID and Ref_ID are the same
			-----------------------------------
			UPDATE T_Mass_Tag_to_Protein_Map
			SET Mass_Tag_Name = @massTagName,
				Cleavage_State = @cleavageState,
				Fragment_Number = @fragmentNumber,
				Fragment_Span = @fragmentSpan,
				Residue_Start = @residueStart,
				Residue_End = @residueEnd,
				Repeat_Count = @repeatCount,
				Terminus_State = @terminusState,
				Missed_Cleavage_Count = @missedCleavageCount
			WHERE Mass_Tag_ID = @Mass_Tag_ID AND Ref_ID = @Ref_ID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0 OR @myRowCount <> 1
			begin
				set @message = 'Row missing (not updated) or multiple rows updated for Mass_Tag_ID = ' 
					+ Convert(varchar(11), @Mass_Tag_ID) + ' and Ref_ID ' + Convert(varchar(11), @Ref_ID)
				set @myError = 75002
				if @AbortOnError <> 0
					goto done
			end
				
	errorCleanup:
			set @count = @count + 1

			if @logLevel >= 1
			Begin
				if @count % 1000 = 0 
				Begin
					if @count % 100000 = 0 Or DateDiff(second, @lastProgressUpdate, GetDate()) >= 300
					Begin
						set @message = '...Processing: ' + convert(varchar(11), @count)
						execute PostLogEntry 'Progress', @message, 'NamePeptides'
						set @message = ''
						set @lastProgressUpdate = GetDate()
					End

					-- Validate that updating is enabled, abort if not enabled
					exec VerifyUpdateEnabled @CallingFunctionDescription = 'NamePeptides', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
					If @UpdateEnabled = 0
						Goto Done
				End
			End			
			
			set @myError = 0
		End

	end  -- end of while loop		


	--------------------------------------------------
	-- Exit
	---------------------------------------------------
Done:
	return @myError


GO
