/****** Object:  StoredProcedure [dbo].[ComparePeptideHitResultsAggregated] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE Procedure ComparePeptideHitResultsAggregated
/****************************************************
**
**	Desc:	Compares the peptide hit results for two jobs (or two sets of jobs) specified using @JobList1 and @JobList2
**			Can compare results from a single search tool or a mix of tools, since the procedure only uses tables T_Peptides and T_Score_Discriminant
**
**			This procedure does not compare results on a dataset-by-dataset basis.  
**			Instead, it constructs a unique list of the peptides from @JobList1 and compares that to the unique list for @JobList2
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	01/04/2013 mem - Initial Version
**			01/07/2013 mem - Added parameter @PairwiseJobComparison
**			01/28/2013 mem - Now passing additional parameters to ComparePeptideHitResultsAggregateWork
**    
*****************************************************/
(
	@JobList1 varchar(max) = '906767',			-- Can be a single job or a comma separated list of jobs
	@JobList2 varchar(max) = '906768',			-- Can be a single job or a comma separated list of jobs
	@MSGFSpecProbThreshold real = 1E-10,
	@ReturnOverlapPeptides tinyint = 0,
	@ReturnAllSet1Peptides tinyint = 0,
	@ReturnAllSet2Peptides tinyint = 0,
	@ReturnSet1OnlyPeptides tinyint = 0,
	@ReturnSet2OnlyPeptides tinyint = 0,
	@PairwiseJobComparison  tinyint = 0,		-- Set this to 1 to compare each job in @JobList1 to each job in @JobList2
	@InfoOnly tinyint = 0
)
AS
	Set NoCount On
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	Declare @S varchar(2048)
	Declare @Join varchar(256)
	Declare @Where varchar(256)

	Declare @Iteration smallint
	Declare @Continue tinyint

	Declare @Set1RecordCount int, @Set2RecordCount int, @OverlapCount int

	-------------------------------------------
	-- Validate the inputs
	-------------------------------------------
	--
	Set @JobList1 = IsNull(@JobList1, '')
	Set @JobList2 = IsNull(@JobList2, '')
	Set @MSGFSpecProbThreshold = IsNull(@MSGFSpecProbThreshold, 1E-10)
	
	Set @ReturnOverlapPeptides  = IsNull(@ReturnOverlapPeptides, '')
	Set @ReturnAllSet1Peptides  = IsNull(@ReturnAllSet1Peptides, '')
	Set @ReturnAllSet2Peptides  = IsNull(@ReturnAllSet2Peptides, '')
	Set @ReturnSet1OnlyPeptides = IsNull(@ReturnSet1OnlyPeptides, '')
	Set @ReturnSet2OnlyPeptides = IsNull(@ReturnSet2OnlyPeptides, '')
	Set @PairwiseJobComparison = IsNull(@PairwiseJobComparison, 0)

	Set @InfoOnly = IsNull(@InfoOnly, 0)
	
	If Len(@JobList1) = 0
	Begin
		print '@JobList1 cannot be empty'
		goto done
	End

	If Len(@JobList2) = 0
	Begin
		print '@JobList2 cannot be empty'
		goto done
	End
		
	CREATE TABLE #Tmp_JobList1 (
		Job int
	)
	CREATE CLUSTERED INDEX #IX_Tmp_JobList1 ON #Tmp_JobList1 (Job)
	
	CREATE TABLE #Tmp_JobList2 (
		Job int
	)	
	CREATE CLUSTERED INDEX #IX_Tmp_JobList2 ON #Tmp_JobList2 (Job)
	

	CREATE TABLE #Tmp_OverlapStats_Overall (
	    Set1ResultsCount int,
	    Set2ResultsCount int,
	    OverlapCount     int,
	    Set1_ToolFirst   varchar(64),
	    Set1_ToolLast    varchar(64),
	    Set2_ToolFirst   varchar(64),
	    Set2_ToolLast    varchar(64)
	)
	
	CREATE TABLE #Tmp_OverlapStats_Pairwise (
	    Job1         int,
	    Job2         int,
	    Dataset1     varchar(128),
	    Dataset2     varchar(128),
	    Job1_Tool    varchar(64),
	    Job2_Tool    varchar(64),
	    Job1_Count   int,
	    Job2_Count   int,
	    OverlapCount int
	)

						                                        
	-- Create the temporary tables used by ComparePeptideHitResultsAggregateWork
	
	CREATE TABLE #Tmp_OverlapJobList1 (
		Job int
	)

	CREATE TABLE #Tmp_OverlapJobList2 (
		Job int
	)
	
	CREATE TABLE #Tmp_OverlapResults ( 
		Set1Count int,
		Set2Count int,
		OverlapCount int
	)
	
	-- Populate #Tmp_JobList1 and #Tmp_JobList2
	--
	INSERT INTO #Tmp_JobList1( Job )
	SELECT DISTINCT DataQ.Value
	FROM T_Analysis_Description TAD
		    INNER JOIN ( SELECT DISTINCT VALUE
		                FROM dbo.udfParseDelimitedIntegerList ( @JobList1, ',' ) ) DataQ
		    ON TAD.Job = DataQ.VALUE
	WHERE TAD.ResultType LIKE '%Peptide_Hit'
	--
	SELECT @myRowcount = @@rowcount, @myError = @@error

	--
	INSERT INTO #Tmp_JobList2( Job )
	SELECT DISTINCT DataQ.Value
	FROM T_Analysis_Description TAD
		    INNER JOIN ( SELECT DISTINCT VALUE
		                FROM dbo.udfParseDelimitedIntegerList ( @JobList2, ',' ) ) DataQ
		    ON TAD.Job = DataQ.VALUE
	WHERE TAD.ResultType LIKE '%Peptide_Hit'
	--
	SELECT @myRowcount = @@rowcount, @myError = @@error
	
	If @InfoOnly <> 0
	Begin
		SELECT 1 AS JobSet, Dataset_ID, Dataset, Job, ResultType, Analysis_Tool
		FROM T_Analysis_Description TAD
		WHERE Job In (Select Job From #Tmp_JobList1)
		UNION
		SELECT 2 AS JobSet, Dataset_ID, Dataset, Job, ResultType, Analysis_Tool
		FROM T_Analysis_Description TAD
		WHERE Job In (Select Job From #Tmp_JobList2)
		ORDER BY JobSet, Dataset_ID, Job
	End

	-------------------------------------------
	-- Compare the peptides from Set1 to the peptides in Set2
	-------------------------------------------
	--
	
	-- First initialize the temporary tables
	--
	TRUNCATE TABLE #Tmp_OverlapJobList1
	TRUNCATE TABLE #Tmp_OverlapJobList2
	TRUNCATE TABLE #Tmp_OverlapResults
	
	INSERT INTO #Tmp_OverlapJobList1 (Job)
	SELECT Job
	FROM #Tmp_JobList1

	INSERT INTO #Tmp_OverlapJobList2 (Job)
	SELECT Job
	FROM #Tmp_JobList2

	-- Now compute the overlap
	--
	Exec ComparePeptideHitResultsAggregateWork @MSGFSpecProbThreshold, 
			@Set1RecordCount output, @Set2RecordCount output, @OverlapCount output, 
			@ReturnOverlapPeptides =@ReturnOverlapPeptides, 
			@ReturnAllSet1Peptides = @ReturnAllSet1Peptides, 
			@ReturnAllSet2Peptides = @ReturnAllSet2Peptides,
			@ReturnSet1OnlyPeptides = @ReturnSet1OnlyPeptides,
			@ReturnSet2OnlyPeptides = @ReturnSet2OnlyPeptides, 
			@PairwiseJobComparisonMode = @PairwiseJobComparison,
			@infoOnly = @infoOnly
		
	-------------------------------------------
	-- Store the overlap stats
	-------------------------------------------
	--
	INSERT INTO #Tmp_OverlapStats_Overall( 
		Set1ResultsCount,
		Set2ResultsCount,
		OverlapCount, 
		Set1_ToolFirst,
		Set1_ToolLast,
		Set2_ToolFirst,
		Set2_ToolLast)
	SELECT @Set1RecordCount,
	       @Set2RecordCount,
	       @OverlapCount,
	       Set1ToolQ.ToolFirst,
	       Set1ToolQ.ToolLast,
	       Set2ToolQ.ToolFirst,
	       Set2ToolQ.ToolLast
	FROM ( SELECT Min(Analysis_Tool) AS ToolFirst,
	              Max(Analysis_Tool) AS ToolLast
	       FROM T_Analysis_Description
	       WHERE Job IN ( SELECT Job FROM #Tmp_JobList1 ) 
	     ) AS Set1ToolQ
	     CROSS JOIN
	     ( SELECT Min(Analysis_Tool) AS ToolFirst,
	              Max(Analysis_Tool) AS ToolLast
	       FROM T_Analysis_Description
	       WHERE Job IN ( SELECT Job FROM #Tmp_JobList2 ) 
	     ) AS Set2ToolQ


	If @PairwiseJobComparison <> 0
	Begin
		Declare @Job1 int, @Job2 int
		Declare @Dataset1 varchar(128), @Dataset2 varchar(128)
		Declare @Job1Tool varchar(64), @Job2Tool varchar(64)
		Declare @continueA tinyint, @continueB tinyint
		
		Set @continueA = 1
		Set @Job1 = 0
		
		While @continueA = 1
		Begin
			SELECT TOP 1 @Job1 = TAD.Job,
			             @Dataset1 = TAD.Dataset,
			             @Job1Tool = TAD.Analysis_Tool
			FROM #Tmp_JobList1
			     INNER JOIN T_Analysis_Description TAD
			       ON #Tmp_JobList1.Job = TAD.Job
			WHERE TAD.Job > @Job1
			ORDER BY TAD.Job
			
			If @@RowCount = 0
				Set @continueA = 0
			Else
			Begin
				Set @continueB = 1
				Set @Job2 = 0
				
				While @continueB = 1
				Begin
				
					SELECT TOP 1 @Job2 = TAD.Job,
					             @Dataset2 = TAD.Dataset,
					             @Job2Tool = TAD.Analysis_Tool
					FROM #Tmp_JobList2
					     INNER JOIN T_Analysis_Description TAD
					 ON #Tmp_JobList2.Job = TAD.Job
					WHERE TAD.Job > @Job2
					ORDER BY TAD.Job
					
					If @@RowCount = 0
						Set @continueB = 0
					Else
					Begin
					
						TRUNCATE TABLE #Tmp_OverlapJobList1
						TRUNCATE TABLE #Tmp_OverlapJobList2
						TRUNCATE TABLE #Tmp_OverlapResults
						
						INSERT INTO #Tmp_OverlapJobList1 (Job)
						VALUES (@Job1)

						INSERT INTO #Tmp_OverlapJobList2 (Job)
						VALUES (@Job2)
						
						-- Now compute the overlap
						--
						Exec ComparePeptideHitResultsAggregateWork @MSGFSpecProbThreshold, 
								@Set1RecordCount output, @Set2RecordCount output, @OverlapCount output, 
								@ReturnOverlapPeptides =@ReturnOverlapPeptides, 
								@ReturnAllSet1Peptides = @ReturnAllSet1Peptides, 
								@ReturnAllSet2Peptides = @ReturnAllSet2Peptides,
								@ReturnSet1OnlyPeptides = @ReturnSet1OnlyPeptides,
								@ReturnSet2OnlyPeptides = @ReturnSet2OnlyPeptides, 
								@PairwiseJobComparisonMode = @PairwiseJobComparison,
								@infoOnly = @infoOnly

						
						INSERT INTO #Tmp_OverlapStats_Pairwise( Job1, Job2,
						                                        Dataset1, Dataset2,
						                                        Job1_Tool, Job2_Tool,
						                                        Job1_Count, Job2_Count,
						                                        OverlapCount )
						VALUES (@Job1, @Job2, 
						        @Dataset1, @Dataset2, 
						        @Job1Tool, @Job2Tool, 
						        @Set1RecordCount, @Set2RecordCount, @OverlapCount)

	       					
						
					End
				End
				
			End
		End
	End


	SELECT *,
		    CASE
		    WHEN Set1ResultsCount > 0 THEN OverlapCount / Convert(real, Set1ResultsCount)
		        ELSE 0
		    END AS Fraction_Set1_InCommon,
		    CASE
		        WHEN Set2ResultsCount > 0 THEN OverlapCount / Convert(real, Set2ResultsCount)
		        ELSE 0
		    END AS Fraction_Set2_InCommon
	FROM #Tmp_OverlapStats_Overall

	If @PairwiseJobComparison <> 0
	Begin
		SELECT *,
			    CASE
			        WHEN Job1_Count > 0 THEN OverlapCount / Convert(real, Job1_Count)
			        ELSE 0
			    END AS Fraction_Job1_InCommon,
			    CASE
			        WHEN Job2_Count > 0 THEN OverlapCount / Convert(real, Job2_Count)
			        ELSE 0
			    END AS Fraction_Job2_InCommon
		FROM #Tmp_OverlapStats_Pairwise
		ORDER BY Job1, Job2

	End
	

	-----------------------------------------------
	-- exit the stored procedure
	-----------------------------------------------
	-- 
Done:

	return @myError


GO
