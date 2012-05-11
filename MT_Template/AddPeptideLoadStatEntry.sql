/****** Object:  StoredProcedure [dbo].[AddPeptideLoadStatEntry] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE AddPeptideLoadStatEntry
/****************************************************
**
**	Desc: 
**		Adds a new entry to T_Peptide_Load_Stats
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	09/12/2006
**			01/06/2012 mem - Updated to use T_Peptides.Job
**    
*****************************************************/
(
	@DiscriminantScoreMinimum real = 0,
	@PeptideProphetMinimum real = 0,
	@AnalysisStateMatch int = 7,
	@InfoOnly tinyint = 0,
	@JobDateMax datetime = '12/31/9999'			-- Ignored if >= '12/31/9999'
)
AS
	set nocount on

	Declare @myRowCount int
	Declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	Declare @JobCount int
	Declare @PeptideCountUnfiltered int
	Declare @PMTCountUnfiltered int
	Declare @PeptideCountFiltered int
	Declare @PMTCountFiltered int
	Declare @EntryDate datetime
	
	Declare @AMTCollectionID int
	
	Set @JobCount = 0
	Set @PeptideCountUnfiltered = 0
	Set @PMTCountUnfiltered = 0
	Set @PeptideCountFiltered = 0
	Set @PMTCountFiltered = 0
	
	-----------------------------------------------------
	-- Validate the inputs
	-----------------------------------------------------
	Set @DiscriminantScoreMinimum = IsNull(@DiscriminantScoreMinimum, 0)
	Set @PeptideProphetMinimum = IsNull(@PeptideProphetMinimum, 0)
	Set @JobDateMax = IsNull(@JobDateMax, '12/31/9999')
	
	CREATE TABLE #Tmp_Job_List (
		Job int NOT NULL
	)
	
	-----------------------------------------------------
	-- Populate #Tmp_Job_List with the jobs in T_Analysis_Description
	-- that have state @AnalysisStateMatch
	-----------------------------------------------------
	INSERT #Tmp_Job_List (Job)
	SELECT Job
	FROM T_Analysis_Description
	WHERE State = @AnalysisStateMatch AND
		  (@JobDateMax >= '12/31/9999' OR 
		   IsNull(Created_PMT_Tag_DB, '1/1/1900') <= @JobDateMax)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	Set @JobCount = @myRowCount

	Set @PeptideCountUnfiltered = 0
	Set @PMTCountUnfiltered = 0

	If @JobDateMax >= '12/31/9999'
	Begin
		Set @EntryDate = GetDate()

		-----------------------------------------------------
		-- Count the number of rows in T_Peptides
		-----------------------------------------------------
		SELECT @PeptideCountUnfiltered = TableRowCount
		FROM V_Table_Row_Counts
		WHERE TableName = 'T_Peptides'
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		-----------------------------------------------------
		-- Count the number of entries in T_Mass_Tags, excluding
		-- entries with Internal_Standard_Only = 1
		-----------------------------------------------------
		SELECT @PMTCountUnfiltered = COUNT(*)
		FROM T_Mass_Tags
		WHERE Internal_Standard_Only <> 1
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
	End
	Else
	Begin
		Set @EntryDate = @JobDateMax

		-----------------------------------------------------
		-- Count the number of rows in T_Peptides and
		-- the number of PMT Tags defined, filtering on
		-- jobs in #Tmp_Job_List
		-----------------------------------------------------
		SELECT @PeptideCountUnfiltered = Count(*),
			   @PMTCountUnfiltered = Count(Distinct P.Mass_Tag_ID)
		FROM #Tmp_Job_List INNER JOIN 
			 T_Peptides P ON #Tmp_Job_List.Job = P.Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
	End
	

	If @DiscriminantScoreMinimum = 0 AND @PeptideProphetMinimum = 0
	Begin
		Set @PeptideCountFiltered = @PeptideCountUnfiltered
		Set @PMTCountFiltered = @PMTCountUnfiltered
	End
	Else
	Begin
		Set @PeptideCountFiltered = 0
		Set @PMTCountFiltered = 0
		
		SELECT	@PeptideCountFiltered = COUNT(*), 
				@PMTCountFiltered = COUNT(Distinct P.Mass_Tag_ID)
		FROM #Tmp_Job_List INNER JOIN T_Peptides P ON
			 #Tmp_Job_List.Job = P.Job INNER JOIN
			 T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID
		WHERE (@DiscriminantScoreMinimum = 0 OR IsNull(SD.DiscriminantScoreNorm, 0) >= @DiscriminantScoreMinimum) AND
			  (@PeptideProphetMinimum = 0 OR IsNull(SD.Peptide_Prophet_Probability, 0) >= @PeptideProphetMinimum)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
	End
	

	If @InfoOnly <> 0
		SELECT	@EntryDate AS Entry_Date,
				@JobCount AS JobCount, 
				@PeptideCountUnfiltered AS PeptideCountUnfiltered,
				@PMTCountUnfiltered AS PMTCountUnfiltered,
				@PeptideCountFiltered AS PeptideCountFiltered,
				@PMTCountFiltered AS PMTCountFiltered
	Else
		INSERT INTO T_Peptide_Load_Stats (
			Entry_Date, Jobs, Peptides_Unfiltered, PMTs_Unfiltered, 
			Peptides_Filtered, PMTs_Filtered, Discriminant_Score_Minimum, Peptide_Prophet_Minimum
		)
		VALUES 	(@EntryDate, @JobCount, @PeptideCountUnfiltered, @PMTCountUnfiltered, 
				 @PeptideCountFiltered, @PMTCountFiltered, @DiscriminantScoreMinimum, @PeptideProphetMinimum)

	
Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[AddPeptideLoadStatEntry] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AddPeptideLoadStatEntry] TO [MTS_DB_Lite] AS [dbo]
GO
