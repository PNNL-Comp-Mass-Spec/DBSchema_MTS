/****** Object:  StoredProcedure [dbo].[ComparePeptideHitResultsMSGF] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure ComparePeptideHitResultsMSGF
/****************************************************
**
**	Desc:	Compares the peptide hit results for two jobs (or two sets of jobs) specified using @JobList1 and @JobList2
**			Can compare results from a single search tool or a mix of tools, since the procedure only uses tables T_Peptides and T_Score_Discriminant
**			However, will only compare data on a dataset-by-dataset basis
**
**			Alternatively, specify a list of datasets using either @Datasets or @DatasetIDs
**			When specifying datasets, this procedure will determine the two most commonly used peptide_hit tools and use those to populate @JobList1 and @JobList2
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	01/04/2013 mem - Initial Version
**			01/07/2013 mem - Added parameters @Datasets and @DatasetIDs
**			01/28/2013 mem - Now ignoring @Datasets and @DatasetIDs if @JobList1 and @JobList2 are defined
**			02/15/2013 mem - Now returning FDR and PepFDR values when @ReturnOverlapPeptides=1 and comparing MSGF+ results
**			10/22/2013 mem - Added @MaxFDR
**    
*****************************************************/
(
	@Datasets varchar(max) = '',					-- Can be a comma separated list
	@DatasetIDs varchar(max) = '300689, 300690',	-- Can be a comma separated list
	@JobList1 varchar(max) = '',					-- Can be a single job or a comma separated list of jobs
	@JobList2 varchar(max) = '',					-- Can be a single job or a comma separated list of jobs
	@CountUniquePeptides tinyint = 0,				-- When 0, then returns PSM counts; otherwise, returns Unique Peptide counts
	@MaxFDR real = -1,								-- Maximum FDR value (ignored if < 0)
	@ReturnOverlapPeptides tinyint=0,
	@ReturnAllSet1Peptides tinyint=0,
	@ReturnAllSet2Peptides tinyint=0,
	@ReturnSet1OnlyPeptides tinyint=0,
	@ReturnSet2OnlyPeptides tinyint=0,
	@InfoOnly tinyint = 0
)
AS
	Set NoCount On
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @Dataset varchar(256)
	Declare @DatasetID int
	
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
	Set @Datasets = IsNull(@Datasets, '')
	Set @DatasetIDs = IsNull(@DatasetIDs, '')
	Set @JobList1 = IsNull(@JobList1, '')
	Set @JobList2 = IsNull(@JobList2, '')
	Set @CountUniquePeptides = IsNull(@CountUniquePeptides, 0)
	
	Set @ReturnOverlapPeptides  = IsNull(@ReturnOverlapPeptides, '')
	Set @ReturnAllSet1Peptides  = IsNull(@ReturnAllSet1Peptides, '')
	Set @ReturnAllSet2Peptides  = IsNull(@ReturnAllSet2Peptides, '')
	Set @ReturnSet1OnlyPeptides = IsNull(@ReturnSet1OnlyPeptides, '')
	Set @ReturnSet2OnlyPeptides = IsNull(@ReturnSet2OnlyPeptides, '')

	Set @InfoOnly = IsNull(@InfoOnly, 0)

	If Len(@JobList1) > 0 And Len(@JobList2) = 0 
	Begin
		Print 'Because @JobList1 is defined, you must also define @JobList2'
		Return 1
	End

	If Len(@JobList1) = 0 And Len(@JobList2) > 0 
	Begin
		Print 'Because @JobList2 is defined, you must also define @JobList1'
		Return 1
	End

	If Len(@JobList1) > 0 And Len(@JobList2) > 0 
	Begin
		If @Datasets <> ''
		Begin
			print 'Ignoring value for @Datasets (' + @Datasets + ') since @JobList1 and @JobList2 are defined'
			Set @Datasets = ''
		End

		If @DatasetIDs <> ''
		Begin
			print 'Ignoring value for @DatasetIDs (' + @DatasetIDs + ') since @JobList1 and @JobList2 are defined'
			Set @DatasetIDs = ''
		End
	End
	
	CREATE TABLE #TmpJobList1 (
		Job int
	)
	
	CREATE TABLE #TmpJobList2 (
		Job int
	)

	CREATE TABLE #TmpDatasets (
		Dataset_ID int
	)
	
	CREATE TABLE #TmpSet2 (
		Dataset_ID int,
		Job int,
		Scan_Number int,
		Charge_State smallint,
		Seq_ID int NULL,
		MSGF_SpecProb real NULL,
		FDR real NULL,
		PepFDR real NULL
	)
	CREATE INDEX #IX_TmpSet2_DatasetID ON #TmpSet2 (Dataset_ID)
	CREATE INDEX #IX_TmpSet2_Values ON #TmpSet2 (Dataset_ID, Scan_Number, Charge_State, Seq_ID)
	
	CREATE TABLE #TmpSet1 (
		Dataset_ID int,
		Job int,
		Scan_Number int,
		Charge_State smallint,
		Seq_ID int NULL,
		MSGF_SpecProb real NULL,
		FDR real NULL,
		PepFDR real NULL
	)
	
	CREATE INDEX IX_TmpSet1_DatasetID ON #TmpSet1 (Dataset_ID)
	CREATE INDEX IX_TmpSet1_Values ON #TmpSet1 (Dataset_ID, Scan_Number, Charge_State, Seq_ID)
	
	CREATE TABLE #TmpStats ( 
		Dataset_ID int,
		Dataset varchar(256),
		Set1ResultsCount int,
		Set2ResultsCount int,
		OverlapCount int
	)

	
	If Len(@Datasets) = 0 And Len(@DatasetIDs) = 0
	Begin
		-- Jobs must be defined
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
			
		-- Populate #TmpJobList1 and #TmpJobList2
		--
		INSERT INTO #TmpJobList1( Job )
		SELECT DISTINCT DataQ.Value
		FROM T_Analysis_Description TAD
				INNER JOIN ( SELECT DISTINCT Value
							FROM dbo.udfParseDelimitedIntegerList ( @JobList1, ',' ) ) DataQ
				ON TAD.Job = DataQ.Value
		WHERE TAD.ResultType LIKE '%Peptide_Hit'
		--
		SELECT @myRowcount = @@rowcount, @myError = @@error

		--
		INSERT INTO #TmpJobList2( Job )
		SELECT DISTINCT DataQ.Value
		FROM T_Analysis_Description TAD
				INNER JOIN ( SELECT DISTINCT Value
							FROM dbo.udfParseDelimitedIntegerList ( @JobList2, ',' ) ) DataQ
				ON TAD.Job = DataQ.Value
		WHERE TAD.ResultType LIKE '%Peptide_Hit'
		--
		SELECT @myRowcount = @@rowcount, @myError = @@error
			
		INSERT INTO #TmpDatasets( Dataset_ID )
		SELECT DISTINCT TAD.Dataset_ID
		FROM T_Analysis_Description TAD
		WHERE Job In (Select Job From #TmpJobList1 UNION Select Job From #TmpJobList2)
		
	End
	Else
	Begin
		If Len(@Datasets) > 0 
		Begin
			INSERT INTO #TmpDatasets( Dataset_ID )
			SELECT DISTINCT TAD.Dataset_ID
			FROM T_Analysis_Description TAD
			     INNER JOIN ( SELECT DISTINCT Value
			                  FROM dbo.udfParseDelimitedList ( @Datasets, ',' ) ) DataQ
			       ON TAD.Dataset = DataQ.Value
			WHERE TAD.ResultType LIKE '%Peptide_Hit'
		End
		
		If Len(@DatasetIDs) > 0
		Begin
			INSERT INTO #TmpDatasets( Dataset_ID )
			SELECT DISTINCT TAD.Dataset_ID
			FROM T_Analysis_Description TAD
			     INNER JOIN ( SELECT DISTINCT Value
			                  FROM dbo.udfParseDelimitedIntegerList ( @DatasetIDs, ',' ) ) DataQ
			       ON TAD.Dataset_ID = DataQ.Value
			WHERE TAD.ResultType LIKE '%Peptide_Hit'
		End

		CREATE TABLE #TmpPeptideHitResultTypes (
			Entry_ID int identity(1,1) NOT NULL,
			ResultType varchar(32)			
		)
		
		
		-- Determine the two most common peptide_hit result types for datasets in #TmpDatasets
		
		INSERT INTO #TmpPeptideHitResultTypes (ResultType)
		SELECT TOP 2 ResultType
		FROM ( SELECT ResultType,
		              Row_Number() OVER ( PARTITION BY ResultType ORDER BY JobCount DESC ) AS UsageRank
		       FROM ( SELECT ResultType,
		                     COUNT(*) AS JobCount
		              FROM T_Analysis_Description
		              WHERE ResultType LIKE '%Peptide_Hit' AND
		                    Dataset_ID IN ( SELECT Dataset_ID FROM #TmpDatasets )
		              GROUP BY ResultType 
		            ) AS InnerQ 
		     ) RankQ
		ORDER BY UsageRank, ResultType

	
		INSERT INTO #TmpJobList1 ( Job )
		SELECT TAD.Job
		FROM T_Analysis_Description TAD
		     INNER JOIN #TmpPeptideHitResultTypes RT
		       ON TAD.ResultType = RT.ResultType
		WHERE RT.Entry_ID = 1 AND
		      TAD.Dataset_ID IN ( SELECT Dataset_ID FROM #TmpDatasets )

		INSERT INTO #TmpJobList2 ( Job )
		SELECT TAD.Job
		FROM T_Analysis_Description TAD
		     INNER JOIN #TmpPeptideHitResultTypes RT
		       ON TAD.ResultType = RT.ResultType
		WHERE RT.Entry_ID = 2 AND
		      TAD.Dataset_ID IN ( SELECT Dataset_ID FROM #TmpDatasets )

		If @InfoOnly <> 0
		Begin
			SELECT Dataset, Job, ResultType
			FROM T_Analysis_Description
			WHERE Job IN ( SELECT Job FROM #TmpJobList1 ) OR
			      Job IN ( SELECT Job FROM #TmpJobList2 )
			ORDER BY Dataset, ResultType, Job
		End		

	End


			
	If @InfoOnly <> 0
	Begin
		SELECT DISTINCT TAD.Dataset_ID, TAD.Dataset, TAD.Job, TAD.ResultType, TAD.Analysis_Tool
		FROM #TmpDatasets DS
		     INNER JOIN T_Analysis_Description TAD
		       ON DS.Dataset_ID = TAD.Dataset_ID
		WHERE Job In (Select Job From #TmpJobList1 UNION Select Job From #TmpJobList2)
		ORDER BY TAD.Dataset_ID
	End

	SELECT 'Set1' As SetName, ResultType, COUNT(*) AS Jobs
	FROM T_Analysis_Description
	WHERE Job In (SELECT Job FROM #TmpJobList1)
	GROUP BY ResultType
	UNION
	SELECT 'Set2' As SetName, ResultType, COUNT(*) AS Jobs
	FROM T_Analysis_Description
	WHERE Job In (SELECT Job FROM #TmpJobList2)
	GROUP BY ResultType
	
	
	-- Initialize @DatasetID
	SELECT @DatasetID = MIN(Dataset_ID)-1
	FROM #TmpDatasets

	-- Cycle through the entries in #TmpDatasets
	
	Set @Continue = 1
	While @Continue = 1
	Begin -- <a>
		SELECT TOP 1 @Dataset = TAD.Dataset,
		             @DatasetID = TAD.Dataset_ID
		FROM #TmpDatasets DS
		     INNER JOIN T_Analysis_Description TAD
		       ON DS.Dataset_ID = TAD.Dataset_ID
		WHERE TAD.Dataset_ID > @DatasetID
		ORDER BY TAD.Dataset_ID
		--
		SELECT @myRowcount = @@rowcount, @myError = @@error

		If @myRowcount = 0
			Set @Continue = 0
		Else
		Begin -- <b>

			-------------------------------------------
			-- Find the Peptides seen for this dataset in Set2
			-------------------------------------------
			--
			If @CountUniquePeptides = 0
			Begin
				INSERT INTO #TmpSet2( Dataset_ID,
										Job,
										Scan_Number,
										Charge_State,
										Seq_ID,
										MSGF_SpecProb, 
										FDR, 
										PepFDR )
				SELECT TAD.Dataset_ID,
					TAD.Job,
					P.Scan_Number,
					P.Charge_State,
					P.Seq_ID,
					SD.MSGF_SpecProb,
					DB.FDR,
					DB.PepFDR
				FROM T_Peptides P			     
					INNER JOIN T_Analysis_Description TAD
					  ON P.Job = TAD.Job
					INNER JOIN #TmpJobList2
					  ON TAD.Job = #TmpJobList2.Job
					INNER JOIN T_Score_Discriminant SD
					  ON P.Peptide_ID = SD.Peptide_ID
					LEFT OUTER JOIN T_Score_MSGFDB DB
					  ON P.Peptide_ID = DB.Peptide_ID
				WHERE (TAD.Dataset = @Dataset) AND Not Seq_ID Is Null AND 
				      (@MaxFDR < 0 OR IsNull(FDR, 1) <= @MaxFDR)
				--
				Set @Set2RecordCount = @@RowCount
			End
			Else
			Begin
				INSERT INTO #TmpSet2( Dataset_ID,
										Job,
										Scan_Number,
										Charge_State,
										Seq_ID,
										MSGF_SpecProb, 
										FDR, 
										PepFDR )
				SELECT Dataset_ID,
				       Job,
				       Scan_Number,
				       Charge_State,
				       Seq_ID,
				       MSGF_SpecProb,
					   FDR,
					   PepFDR
				FROM ( SELECT TAD.Dataset_ID,
				              TAD.Job,
				              P.Scan_Number,
				              P.Charge_State,
				              P.Seq_ID,
				              SD.MSGF_SpecProb,
					          DB.FDR,
					          DB.PepFDR,
				              Row_Number() OVER ( Partition BY TAD.Job, P.Seq_ID ORDER BY SD.MSGF_SpecProb ) AS ScoreRank
				       FROM T_Peptides P
				            INNER JOIN T_Analysis_Description TAD
				              ON P.Job = TAD.Job
				            INNER JOIN #TmpJobList2
				              ON TAD.Job = #TmpJobList2.Job
				            INNER JOIN T_Score_Discriminant SD
				              ON P.Peptide_ID = SD.Peptide_ID
				            LEFT OUTER JOIN T_Score_MSGFDB DB
					          ON P.Peptide_ID = DB.Peptide_ID
				       WHERE (TAD.Dataset = @Dataset) AND
				             NOT Seq_ID IS NULL AND 
				             (@MaxFDR < 0 OR IsNull(FDR, 1) <= @MaxFDR)
				      ) AS RankQ
				WHERE ScoreRank = 1
				--
				Set @Set2RecordCount = @@RowCount
			End
			
			
			-- Update@Set2RecordCount to report the unique number of records 
			-- (necessary in case this dataset had multiple jobs in Set2)
			--
			SELECT @Set2RecordCount = COUNT(*)
			FROM (
				SELECT DISTINCT Scan_Number,
								Charge_State,
								Seq_ID
				FROM #TmpSet2
				WHERE Dataset_ID = @DatasetID
			) DistinctQ


			-------------------------------------------
			-- Find the Set1 Peptides
			-------------------------------------------
			--
			If @CountUniquePeptides = 0
			Begin
				INSERT INTO #TmpSet1( Dataset_ID,
										Job,
										Scan_Number,
										Charge_State,
										Seq_ID,
										MSGF_SpecProb, 
										FDR, 
										PepFDR )
				SELECT TAD.Dataset_ID,
					TAD.Job,
					P.Scan_Number,
					P.Charge_State,
					P.Seq_ID,
					SD.MSGF_SpecProb,
					DB.FDR,
					DB.PepFDR
				FROM T_Peptides P			     
					INNER JOIN T_Analysis_Description TAD
					 ON P.Job = TAD.Job
					INNER JOIN #TmpJobList1
					 ON TAD.Job = #TmpJobList1.Job
					INNER JOIN T_Score_Discriminant SD
					 ON P.Peptide_ID = SD.Peptide_ID
					LEFT OUTER JOIN T_Score_MSGFDB DB
					  ON P.Peptide_ID = DB.Peptide_ID
				WHERE (TAD.Dataset = @Dataset) AND Not Seq_ID Is Null AND 
				      (@MaxFDR < 0 OR IsNull(FDR, 1) <= @MaxFDR)
				--
				Set @Set1RecordCount = @@RowCount
			End
			Else
			Begin
				INSERT INTO #TmpSet1( Dataset_ID,
										Job,
										Scan_Number,
										Charge_State,
										Seq_ID,
										MSGF_SpecProb, 
										FDR, 
										PepFDR )
				SELECT Dataset_ID,
				       Job,
				       Scan_Number,
				       Charge_State,
				       Seq_ID,
				       MSGF_SpecProb,
					   FDR,
					   PepFDR
				FROM ( SELECT TAD.Dataset_ID,
				              TAD.Job,
				              P.Scan_Number,
				              P.Charge_State,
				              P.Seq_ID,
				              SD.MSGF_SpecProb,
					          DB.FDR,
					          DB.PepFDR,
				              Row_Number() OVER ( Partition BY TAD.Job, P.Seq_ID ORDER BY SD.MSGF_SpecProb ) AS ScoreRank
				       FROM T_Peptides P
				            INNER JOIN T_Analysis_Description TAD
				              ON P.Job = TAD.Job
				            INNER JOIN #TmpJobList1
				              ON TAD.Job = #TmpJobList1.Job
				            INNER JOIN T_Score_Discriminant SD
				              ON P.Peptide_ID = SD.Peptide_ID
				            LEFT OUTER JOIN T_Score_MSGFDB DB
					          ON P.Peptide_ID = DB.Peptide_ID
				       WHERE (TAD.Dataset = @Dataset) AND
				             NOT Seq_ID IS NULL AND 
				             (@MaxFDR < 0 OR IsNull(FDR, 1) <= @MaxFDR)
				     ) AS RankQ
				WHERE ScoreRank = 1
				--
				Set @Set1RecordCount = @@RowCount
			End
			
			-- Update @Set1RecordCount to report the unique number of records 
			-- (necessary in case this dataset had multiple jobs in set1)
			--
			SELECT @Set1RecordCount = COUNT(*)
			FROM (
				SELECT DISTINCT Scan_Number,
								Charge_State,
								Seq_ID
				FROM #TmpSet1
				WHERE Dataset_ID = @DatasetID
			) DistinctQ


			-------------------------------------------
			-- Count the number of overlapping peptides for this Dataset
			-------------------------------------------
			--	
			If @CountUniquePeptides = 0
			Begin
				SELECT @OverlapCount = COUNT(*)
				FROM ( SELECT DISTINCT Set2.Scan_Number,
									Set2.Charge_State,
									Set2.Seq_ID
					FROM #TmpSet2 Set2
							INNER JOIN #TmpSet1 Set1
							ON Set2.Dataset_ID = Set1.Dataset_ID AND
								Set2.Scan_Number = Set1.Scan_Number AND
								Set2.Charge_State = Set1.Charge_State AND
								Set2.Seq_ID = Set1.Seq_ID
					WHERE Set1.Dataset_ID = @DatasetID  
					) OverlapQ
			End
			Else
			Begin
				SELECT @OverlapCount = COUNT(*)
				FROM ( SELECT DISTINCT Set2.Seq_ID
				       FROM #TmpSet2 Set2
				            INNER JOIN #TmpSet1 Set1
				              ON Set2.Dataset_ID = Set1.Dataset_ID AND
				                 Set2.Seq_ID = Set1.Seq_ID
				       WHERE Set1.Dataset_ID = @DatasetID 
				     ) OverlapQ
			End
			
			-------------------------------------------
			-- Store the overlap stats
			-------------------------------------------
			--
			INSERT INTO #TmpStats( Dataset_ID,
			                       Dataset,
			      Set1ResultsCount,
			                       Set2ResultsCount,
			                       OverlapCount )
			VALUES(@DatasetID, @Dataset, @Set1RecordCount, @Set2RecordCount, @OverlapCount)

		End -- </b>
		
		If @InfoOnly <> 0
			Set @Continue = 0

	End -- </a>

	If @InfoOnly = 0
	Begin -- <c>
		SELECT *,
		       CASE
		           WHEN Set1ResultsCount > 0 THEN OverlapCount / Convert(real, Set1ResultsCount)
		           ELSE 0
		       END AS FractionInCommon_Set1,
		       CASE
		           WHEN Set2ResultsCount > 0 THEN OverlapCount / Convert(real, Set2ResultsCount)
		           ELSE 0
		       END AS FractionInCommon_Set2
		FROM #TmpStats
		ORDER BY Dataset

		-------------------------------------------
		-- Return the actual peptides, as dictated by the @Return switches
		-------------------------------------------
		--
		Set @Iteration = 0
		While @Iteration <= 4
		Begin -- <d>
			-- Overlapping peptides
			If @Iteration = 0
				Set @Join = '#TmpSet2 Set2 INNER JOIN #TmpSet1 Set1'

			-- All Set1 peptides
			If @Iteration = 1 OR @Iteration = 2
				Set @Join = '#TmpSet1 Set1 LEFT OUTER JOIN #TmpSet2 Set2'

			-- All Set2 peptides
			If @Iteration = 3 or @Iteration = 4
				Set @Join = '#TmpSet2 Set2 LEFT OUTER JOIN #TmpSet1 Set1'

			Set @Where = ''
			If @Iteration = 2
				Set @Where = ' WHERE Set2.MSGF_SpecProb Is Null'

			If @Iteration = 4
				Set @Where = ' WHERE Set1.MSGF_SpecProb Is Null'

			If  @Iteration = 0 And @ReturnOverlapPeptides <> 0 Or
				@Iteration = 1 And @ReturnAllSet1Peptides <> 0 Or
				@Iteration = 2 And @ReturnSet1OnlyPeptides <> 0 Or
				@Iteration = 3 And @ReturnAllSet2Peptides <> 0 Or
				@Iteration = 4 And @ReturnSet2OnlyPeptides <> 0
			Begin -- <e>
				Set @S = ''
				Set @S = @S + ' SELECT IsNull(Set2.Dataset_ID,   Set1.Dataset_ID) AS Dataset_ID, '
				Set @S = @S +        ' IsNull(Set2.Scan_Number,  Set1.Scan_Number) AS Scan_Number, '
				Set @S = @S +        ' IsNull(Set2.Charge_State, Set1.Charge_State) AS Charge_State, '
				Set @S = @S +        ' IsNull(Set2.Seq_ID,       Set1.Seq_ID) AS Seq_ID '
				
				If @Iteration = 0
				Begin
					Set @S = @S +    ', Set1.MSGF_SpecProb  AS MSGF_SpecProb_Set1'
					Set @S = @S +    ', Set2.MSGF_SpecProb  AS MSGF_SpecProb_Set2'
					Set @S = @S +    ', Set1.FDR     AS FDR_Set1'
					Set @S = @S +    ', Set2.FDR     AS FDR_Set2'
					Set @S = @S +    ', Set1.PepFDR  AS PepFDR_Set1'
					Set @S = @S +    ', Set2.PepFDR  AS PepFDR_Set2'
				End
				Else
				Begin
					Set @S = @S +    ', IsNull(Set1.MSGF_SpecProb, Set2.MSGF_SpecProb) AS MSGF_SpecProb'
				End
				Set @S = @S + ' FROM ' +  @Join + ' ON '
				Set @S = @S +        ' Set2.Dataset_ID = Set1.Dataset_ID AND '
				Set @S = @S +        ' Set2.Scan_Number = Set1.Scan_Number AND' 
				Set @S = @S +        ' Set2.Charge_State = Set1.Charge_State AND '
				Set @S = @S +        ' Set2.Seq_ID = Set1.Seq_ID'
				Set @S = @S + @Where
				Set @S = @S + ' ORDER BY IsNull(Set2.Dataset_ID,   Set1.Dataset_ID), IsNull(Set2.Charge_State, Set1.Charge_State), IsNull(Set2.Scan_Number,  Set1.Scan_Number)'

				If @InfoOnly <> 0
					Print @S
				Else
					Exec (@S)
			End -- </e>

			Set @Iteration = @Iteration + 1
		End -- </d>
	End -- </c>
	
	drop table #TmpSet2
	drop table #TmpSet1

	-----------------------------------------------
	-- exit the stored procedure
	-----------------------------------------------
	-- 
Done:

	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[ComparePeptideHitResultsMSGF] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ComparePeptideHitResultsMSGF] TO [MTS_DB_Lite] AS [dbo]
GO
