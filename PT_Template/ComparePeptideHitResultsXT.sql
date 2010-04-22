/****** Object:  StoredProcedure [dbo].[ComparePeptideHitResultsXT] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ComparePeptideHitResultsXT
/****************************************************
**
**	Desc:	Compares the peptide hit results for one or more datasets (specified by @Datasets and/or @DatasetIDs and/or @Jobs)
**			This procedure compares Sequest and X!Tandem results
**			If @Jobs is specified, then will assure the results pertain only to the given jobs
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	10/31/2008
**			01/13/2010 mem - Updated for X!Tandem
**    
*****************************************************/
(
	@Datasets varchar(max) = 'QC_Shew_08_03_pt5F-c_6Oct08_Earth_08-08-15',			-- Can be a comma separated list
	@DatasetIDs varchar(max) = '',													-- Can be a comma separated list
	@Jobs varchar(max) = '',														-- Can be a comma separated list
	@ReturnOverlapPeptides tinyint=0,
	@ReturnAllSequestPeptides tinyint=0,
	@ReturnAllXTandemPeptides tinyint=0,
	@ReturnSequestOnlyPeptides tinyint=0,
	@ReturnXTandemOnlyPeptides tinyint=0,
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

	Declare @SequestRecordCount int, @XTandemRecordCount int, @OverlapCount int
	
	-------------------------------------------
	-- Validate the inputs
	-------------------------------------------
	--
	Set @Datasets = IsNull(@Datasets, '')
	Set @DatasetIDs = IsNull(@DatasetIDs, '')
	Set @Jobs = IsNull(@Jobs, '')
	
	Set @ReturnOverlapPeptides     = IsNull(@ReturnOverlapPeptides, '')
	Set @ReturnAllSequestPeptides  = IsNull(@ReturnAllSequestPeptides, '')
	Set @ReturnAllXTandemPeptides  = IsNull(@ReturnAllXTandemPeptides, '')
	Set @ReturnSequestOnlyPeptides = IsNull(@ReturnSequestOnlyPeptides, '')
	Set @ReturnXTandemOnlyPeptides = IsNull(@ReturnXTandemOnlyPeptides, '')

	Set @InfoOnly = IsNull(@InfoOnly, 0)
	
	CREATE TABLE #TmpDatasets (
		Dataset_ID int
	)
	
	CREATE TABLE #TmpJobs (
		Job int
	)
	
	CREATE TABLE #TmpXTandem (
		Dataset_ID int,
		Job int,
		Scan_Number int,
		Charge_State smallint,
		Seq_ID int NULL,
		Hyperscore real NULL,
		Log_EValue real NULL
	)
	CREATE INDEX #IX_TmpXTandem_DatasetID ON #TmpXTandem (Dataset_ID)
	CREATE INDEX #IX_TmpXTandem_Values ON #TmpXTandem (Dataset_ID, Scan_Number, Charge_State, Seq_ID)
	
	CREATE TABLE #TmpSequest (
		Dataset_ID int,
		Job int,
		Scan_Number int,
		Charge_State smallint,
		Seq_ID int NULL,
		XCorr real NULL
	)
	
	CREATE INDEX IX_TmpSequest_DatasetID ON #TmpSequest (Dataset_ID)
	CREATE INDEX IX_TmpSequest_Values ON #TmpSequest (Dataset_ID, Scan_Number, Charge_State, Seq_ID)
	
	CREATE TABLE #TmpStats ( 
		Dataset_ID int,
		Dataset varchar(256),
		SequestResultsCount int,
		XTandemResultsCount int,
		OverlapCount int
	)
	
	-- Parse @Datasets, @DatasetIDs, and @Jobs to populate #TmpDatasets
	
	If @Datasets <> ''
	Begin
		INSERT INTO #TmpDatasets( Dataset_ID )
		SELECT DISTINCT TAD.Dataset_ID
		FROM T_Analysis_Description TAD
		     INNER JOIN ( SELECT DISTINCT Value
		                  FROM dbo.udfParseDelimitedList ( @Datasets, ',' ) ) DataQ
		       ON TAD.Dataset = DataQ.Value
		--
		SELECT @myRowcount = @@rowcount, @myError = @@error
	End
	
	If @DatasetIDs <> ''
	Begin
		INSERT INTO #TmpDatasets( Dataset_ID )
		SELECT DISTINCT TAD.Dataset_ID
		FROM T_Analysis_Description TAD
		     INNER JOIN ( SELECT DISTINCT Value
		                  FROM dbo.udfParseDelimitedIntegerList ( @DatasetIDs, ',' ) ) DataQ
		       ON TAD.Dataset_ID = DataQ.Value
		WHERE NOT TAD.Dataset_ID IN (SELECT Dataset_ID FROM #TmpDatasets)
		--
		SELECT @myRowcount = @@rowcount, @myError = @@error
	End
	
	If @Jobs = ''
	Begin
		INSERT INTO #TmpJobs( Job )
		SELECT DISTINCT Job
		FROM T_Analysis_Description TAD
		     INNER JOIN #TmpDatasets
		       ON #TmpDatasets.Dataset_ID = TAD.Dataset_ID
		WHERE TAD.ResultType LIKE '%Peptide_Hit'
		--
		SELECT @myRowcount = @@rowcount, @myError = @@error

	End
	Else
	Begin
		INSERT INTO #TmpJobs( Job )
		SELECT DISTINCT DataQ.VALUE
		FROM T_Analysis_Description TAD
		     INNER JOIN ( SELECT DISTINCT VALUE
		                  FROM dbo.udfParseDelimitedIntegerList ( @Jobs, ',' ) ) DataQ
		       ON TAD.Job = DataQ.VALUE
		WHERE TAD.ResultType LIKE '%Peptide_Hit'
		--
		SELECT @myRowcount = @@rowcount, @myError = @@error

		
		INSERT INTO #TmpDatasets( Dataset_ID )
		SELECT DISTINCT TAD.Dataset_ID
		FROM T_Analysis_Description TAD
		     INNER JOIN #TmpJobs
		       ON TAD.Job = #TmpJobs.Job
		WHERE NOT TAD.Dataset_ID IN (SELECT Dataset_ID FROM #TmpDatasets)
		--
		SELECT @myRowcount = @@rowcount, @myError = @@error
	End
			
	If @InfoOnly <> 0
		SELECT DISTINCT TAD.Dataset_ID, TAD.Dataset, #TmpJobs.Job, TAD.ResultType, TAD.Analysis_Tool
		FROM #TmpDatasets DS
		     INNER JOIN T_Analysis_Description TAD
		       ON DS.Dataset_ID = TAD.Dataset_ID
		     INNER JOIN #TmpJobs ON TAD.Job = #TmpJobs.Job
		ORDER BY TAD.Dataset_ID


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
			-- Find the XTandem Peptides
			-------------------------------------------
			--
			INSERT INTO #TmpXTandem( Dataset_ID,
			                         Job,
			                         Scan_Number,
			                         Charge_State,
			                         Seq_ID,
			                         Hyperscore,
			                         Log_EValue)
			SELECT TAD.Dataset_ID,
			       TAD.Job,
			       P.Scan_Number,
			       P.Charge_State,
			       P.Seq_ID,
			       X.Hyperscore,
			       X.Log_EVAlue
			FROM T_Score_XTandem X
			     INNER JOIN T_Peptides P
			       ON X.Peptide_ID = P.Peptide_ID
			     INNER JOIN T_Analysis_Description TAD
			       ON P.Analysis_ID = TAD.Job
			     INNER JOIN #TmpJobs 
			       ON TAD.Job = #TmpJobs.Job
			WHERE (TAD.Dataset = @Dataset) AND Not Seq_ID Is Null
			--
			Set @XTandemRecordCount = @@RowCount
			
			-- Update @XTandemRecordCount to report the unique number of records 
			-- (necessary in case this dataset had multiple XTandem jobs)
			--
			SELECT @XTandemRecordCount = COUNT(*)
			FROM (
				SELECT DISTINCT Scan_Number,
								Charge_State,
								Seq_ID
				FROM #TmpXTandem
				WHERE Dataset_ID = @DatasetID
			) DistinctQ


			-------------------------------------------
			-- Find the Sequest Peptides
			-------------------------------------------
			--
			INSERT INTO #TmpSequest( Dataset_ID,
			                         Job,
			                         Scan_Number,
			                         Charge_State,
			                         Seq_ID,
			                         XCorr )
			SELECT TAD.Dataset_ID,
			       TAD.Job,
			       P.Scan_Number,
			       P.Charge_State,
			       P.Seq_ID,
			       SS.XCorr
			FROM T_Peptides P
			     INNER JOIN T_Analysis_Description TAD
			       ON P.Analysis_ID = TAD.Job
			     INNER JOIN T_Score_Sequest SS
			       ON P.Peptide_ID = SS.Peptide_ID
			     INNER JOIN #TmpJobs 
			       ON TAD.Job = #TmpJobs.Job
			WHERE (TAD.Dataset = @Dataset) AND Not Seq_ID Is Null
			--
			Set @SequestRecordCount = @@RowCount
			
			-- Update @SequestRecordCount to report the unique number of records 
			-- (necessary in case this dataset had multiple Sequest jobs)
			--
			SELECT @SequestRecordCount = COUNT(*)
			FROM (
				SELECT DISTINCT Scan_Number,
								Charge_State,
								Seq_ID
				FROM #TmpSequest
				WHERE Dataset_ID = @DatasetID
			) DistinctQ


			-------------------------------------------
			-- Count the number of overlapping peptides for this Dataset
			-------------------------------------------
			--	
			SELECT @OverlapCount = COUNT(*)
			FROM ( SELECT DISTINCT X.Scan_Number,
			                       X.Charge_State,
			                       X.Seq_ID
			       FROM #TmpXTandem X
			            INNER JOIN #TmpSequest S
			              ON X.Dataset_ID = S.Dataset_ID AND
			                 X.Scan_Number = S.Scan_Number AND
			                 X.Charge_State = S.Charge_State AND
			                 X.Seq_ID = S.Seq_ID
			       WHERE X.Dataset_ID = @DatasetID 
			     ) OverlapQ

			-------------------------------------------
			-- Store the overlap stats
			-------------------------------------------
			--
			INSERT INTO #TmpStats( Dataset_ID,
			                       Dataset,
			                       SequestResultsCount,
			                       XTandemResultsCount,
			                       OverlapCount )
			VALUES(@DatasetID, @Dataset, @SequestRecordCount, @XTandemRecordCount, @OverlapCount)

		End -- </b>
		
		If @InfoOnly <> 0
			Set @Continue = 0

	End -- </a>

	If @InfoOnly = 0
	Begin -- <c>
		SELECT * 
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
				Set @Join = '#TmpXTandem X INNER JOIN #TmpSequest S'

			-- All Sequest peptides
			If @Iteration = 1 OR @Iteration = 2
				Set @Join = '#TmpSequest S LEFT OUTER JOIN #TmpXTandem X'

			-- All XTandem peptides
			If @Iteration = 3 or @Iteration = 4
				Set @Join = '#TmpXTandem X LEFT OUTER JOIN #TmpSequest S'

			Set @Where = ''
			If @Iteration = 2
				Set @Where = ' WHERE X.Hyperscore Is Null'

			If @Iteration = 4
				Set @Where = ' WHERE S.XCorr Is Null'

			If  @Iteration = 0 And @ReturnOverlapPeptides <> 0 Or
				@Iteration = 1 And @ReturnAllSequestPeptides <> 0 Or
				@Iteration = 2 And @ReturnSequestOnlyPeptides <> 0 Or
				@Iteration = 3 And @ReturnAllXTandemPeptides <> 0 Or
				@Iteration = 4 And @ReturnXTandemOnlyPeptides <> 0
			Begin -- <e>
				Set @S = ''
				Set @S = @S + ' SELECT IsNull(X.Dataset_ID,   S.Dataset_ID) AS Dataset_ID, '
				Set @S = @S +        ' IsNull(X.Scan_Number,  S.Scan_Number) AS Scan_Number, '
				Set @S = @S +        ' IsNull(X.Charge_State, S.Charge_State) AS Charge_State, '
				Set @S = @S +        ' IsNull(X.Seq_ID,       S.Seq_ID) AS Seq_ID, '
				Set @S = @S +        ' IsNull(S.XCorr, 0)         AS XCorr, '
				Set @S = @S +        ' IsNull(X.Hyperscore, -1000)   AS Hyperscore,'
				Set @S = @S +        ' IsNull(X.Log_EValue, 0) AS Log_EValue'
				Set @S = @S + ' FROM ' +  @Join + ' ON '
				Set @S = @S +        ' X.Dataset_ID = S.Dataset_ID AND '
				Set @S = @S +        ' X.Scan_Number = S.Scan_Number AND' 
				Set @S = @S +        ' X.Charge_State = S.Charge_State AND '
				Set @S = @S +        ' X.Seq_ID = S.Seq_ID'
				Set @S = @S + @Where
				Set @S = @S + ' ORDER BY IsNull(X.Dataset_ID,   S.Dataset_ID), IsNull(X.Charge_State, S.Charge_State), IsNull(X.Scan_Number,  S.Scan_Number)'

				If @InfoOnly <> 0
					Print @S
				Else
					Exec (@S)
			End -- </e>

			Set @Iteration = @Iteration + 1
		End -- </d>
	End -- </c>
	
	drop table #TmpXTandem
	drop table #TmpSequest

	-----------------------------------------------
	-- exit the stored procedure
	-----------------------------------------------
	-- 
Done:

	return @myError


GO
GRANT EXECUTE ON [dbo].[ComparePeptideHitResultsXT] TO [DMS_SP_User] AS [dbo]
GO
