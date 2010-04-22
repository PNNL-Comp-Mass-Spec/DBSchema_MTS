/****** Object:  StoredProcedure [dbo].[PTExportPeptidesForJobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.PTExportPeptidesForJobs
/****************************************************	
**  Desc:	
**		Exports the peptides that were observed in the given
**		analysis jobs and that pass the given threshold values
**
**		If @JobList is empty, then will export all filter-passing entries
**		in T_Peptides (potentially a huge number of rows)
**
**  Return values:	0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	10/30/2009 mem - Initial Version (modelled after PMExportPeptidesForJobs in MT DBs)
**			11/11/2009 mem - Added parameters @ReturnJobInfoTable and @ReturnPeptideToProteinMapTable
**							 Now returning columns Peptide_ID and RankXC
**			03/17/2010 mem - No longer returning old GANET fields when querying T_Analysis_Description
**						   - Fixed bugs that affected export of X!Tandem results
**
****************************************************/
(
	@JobList varchar(max) = '',
	@MinimumDiscriminantScore real = 0,				-- The minimumDiscriminant_Score to allow; 0 to allow all
	@MinimumPeptideProphetProbability real = 0.5,	-- The minimum Peptide_Prophet_Probability value to allow; 0 to allow all
	@MinimumCleavageState smallint = 0,				-- The minimum Cleavage_State to allow; 0 to allow all

	@GroupByPeptide tinyint = 1,					-- If 1, then group by peptide, returning the max value (specified by @MaxValueSelectionMode) for each sequence in each job
	@GroupByChargeState tinyint = 0,				-- If 1, then reports separate values for each charge state; affects how peptides are grouped when @GroupByPeptide = 1; affects Spectral_Count whether or not @GroupByPeptide is 1, though when @GroupByPeptide is 0, then all peptides for the same job will show the same Spectral_Count value
	@MaxValueSelectionMode tinyint = 0,				-- 0 means use Peak_Area, 1 means use Peak_SN_Ratio, 2 means use XCorr or Hyperscore or MQScore, 3 means Log_Evalue (only applicable for XTandem) or FScore (only applicable for Inspect)
	@ReportHighestScoreStatsInJob tinyint = 1,		-- Only applicable if @GroupByPeptide = 1 and if @MaxValueSelectionMode is not 3 or 4; when 1, then finds the entry with the max area or SN_Ratio, but updates the Sequest/X!Tandem score stats to reflect the highest scores in the analysis job

	@MinXCorrFullyTrypticCharge1 real = 1.9,		-- Only used for fully tryptic peptides
	@MinXCorrFullyTrypticCharge2 real = 2.2,		-- Only used for fully tryptic peptides
	@MinXCorrFullyTrypticCharge3 real = 3.75,		-- Only used for fully tryptic peptides
	@MinXCorrPartiallyTrypticCharge1 real = 4.0,	-- Only used if @MinimumCleavageState is < 2; will also be applied to non-tryptic peptides if @MinimumCleavageState is 0
	@MinXCorrPartiallyTrypticCharge2 real = 4.3,	-- Only used if @MinimumCleavageState is < 2; will also be applied to non-tryptic peptides if @MinimumCleavageState is 0
	@MinXCorrPartiallyTrypticCharge3 real = 4.7,	-- Only used if @MinimumCleavageState is < 2; will also be applied to non-tryptic peptides if @MinimumCleavageState is 0
	@MinDelCn2 real = 0.1,

	@JobPeptideFilterTableName varchar(128) = '',	-- If provided, then will filter the results to only include peptides defined in this table; the table must have fields Job and Peptide and the peptides must be in the format A.BCDEFGH.I
	@MaxJobsToProcess int = 0,						-- Maximum number of jobs to process; leave at 0 to process all jobs defined in @JobList or @JobPeptideFilterTableName
	@JobBatchSize int = 5,							-- Number of jobs to process at a time
	
	@CountRowsOnly tinyint = 0,						-- When 1, then populates @PeptideCount and @AMTCount but does not return any data
	@ReturnPeptideTable tinyint = 1,				-- When 1, then returns a table of Peptide IDs and various information
	@ReturnMTTable tinyint = 1,						-- When 1, then returns a table of Mass Tag IDs and various information
	@ReturnProteinTable tinyint = 1,				-- When 1, then also returns a table of Proteins that the Mass Tag IDs map to
	@ReturnProteinMapTable tinyint = 1,				-- When 1, then also returns the mapping information of Seq_ID to Protein
	@ReturnPeptideToProteinMapTable tinyint = 0,	-- When 1, then also returns a table mapping each individual peptide observation to a protein (necessary to see peptides that map to reversed proteins and don't have Seq_ID values)
	@ReturnJobInfoTable tinyint = 0,				-- When 1, then also returns a table describing the analysis jobs
	
	@PeptideCount int = 0 output,					-- The number of peptides that pass the thresholds
	@AMTCount int = 0 output,						-- The number of AMT tags that pass the thresholds
	@PreviewSql tinyint=0,
	@DebugMode tinyint = 0,
	@message varchar(512)='' output
)
AS
	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Declare @SelectionField varchar(32)

	Declare @S nvarchar(max)

	Declare @JobMin int
	Declare @JobMax int
	Declare @JobCount int
	Set @JobCount = 0

	Declare @ResultType varchar(32)
	Declare @JobDescription varchar(64)

	Begin Try
		
		-------------------------------------------------
		-- Validate the inputs
		-------------------------------------------------	

		Set @JobList = IsNull(@JobList, '')

		Set @MinimumDiscriminantScore = IsNull(@MinimumDiscriminantScore, 0)
		Set @MinimumPeptideProphetProbability = IsNull(@MinimumPeptideProphetProbability, 0)
		Set @MinimumCleavageState = IsNull(@MinimumCleavageState, 2)

		Set @GroupByPeptide = IsNull(@GroupByPeptide, 1)
		Set @GroupByChargeState = IsNull(@GroupByChargeState, 0)

		Set @MaxValueSelectionMode = IsNull(@MaxValueSelectionMode, 0)
		If @MaxValueSelectionMode < 0
			Set @MaxValueSelectionMode = 0
		if @MaxValueSelectionMode > 3
			Set @MaxValueSelectionMode = 3

		Set @ReportHighestScoreStatsInJob = IsNull(@ReportHighestScoreStatsInJob, 1)
		
		Set @MinXCorrFullyTrypticCharge1 = IsNull(@MinXCorrFullyTrypticCharge1, 1.9)
		Set @MinXCorrFullyTrypticCharge2 = IsNull(@MinXCorrFullyTrypticCharge2, 2.2)
		Set @MinXCorrFullyTrypticCharge3 = IsNull(@MinXCorrFullyTrypticCharge3, 3.75)

		Set @MinXCorrPartiallyTrypticCharge1 = IsNull(@MinXCorrPartiallyTrypticCharge1, 4.0)
		Set @MinXCorrPartiallyTrypticCharge2 = IsNull(@MinXCorrPartiallyTrypticCharge2, 4.3)
		Set @MinXCorrPartiallyTrypticCharge3 = IsNull(@MinXCorrPartiallyTrypticCharge3, 4.7)

		Set @MinDelCn2 = IsNull(@MinDelCn2, 0.1)

		Set @JobPeptideFilterTableName = LTrim(RTrim(IsNull(@JobPeptideFilterTableName, '')))
		Set @MaxJobsToProcess = IsNull(@MaxJobsToProcess, 0)
		Set @JobBatchSize = IsNull(@JobBatchSize, 5)
		if @JobBatchSize < 1
			Set @JobBatchSize = 1

		Set @CountRowsOnly = IsNull(@CountRowsOnly, 0)
		Set @ReturnPeptideTable = IsNull(@ReturnPeptideTable, 1)
		Set @ReturnMTTable = IsNull(@ReturnMTTable, 1)
		Set @ReturnProteinTable = IsNull(@ReturnProteinTable, 1)
		Set @ReturnProteinMapTable = IsNull(@ReturnProteinMapTable, 1)
		Set @ReturnPeptideToProteinMapTable = IsNull(@ReturnPeptideToProteinMapTable, 1)
		Set @ReturnJobInfoTable = IsNull(@ReturnJobInfoTable, 1)
		
		If @CountRowsOnly <> 0
		Begin
			Set @ReturnPeptideTable = 0
			Set @ReturnMTTable = 0
			Set @ReturnProteinTable = 0
			Set @ReturnProteinMapTable = 0
		End
	
		Set @PeptideCount = 0
		Set @AMTCount = 0

		Set @PreviewSql = IsNull(@PreviewSql, 0)
		Set @DebugMode = IsNull(@DebugMode, 0)
		
		Set @message = ''


		--------------------------------------------------------------
		-- Parse out each of the jobs in @JobList
		-- Populate #TmpJobList with the job numbers and Result_Type of each job
		-- If @JobList is empty, but @JobPeptideFilterTableName is defined, then examine
		--  @JobPeptideFilterTableName to determine the job numbers
		--------------------------------------------------------------

		Set @CurrentLocation = 'Initialize #TmpJobList'
		
		CREATE TABLE #TmpJobList (
			Job int NOT NULL ,
			ResultType varchar(32) NULL
		)

		-- Add a clustered index on ResultType and Job
		CREATE CLUSTERED INDEX #IX_TmpJobList_ResultType ON #TmpJobList (ResultType, Job)

		-- Add an index to #TmpJobList
		CREATE INDEX IX_TmpJobList_Job ON #TmpJobList(Job)

		
		CREATE TABLE #TmpJobsCurrentBatch (
			Job int NOT NULL
		)

		CREATE CLUSTERED INDEX #IX_TmpJobsCurrentBatch ON #TmpJobsCurrentBatch (Job)
		
		If Len(@JobList) = 0 And Len(@JobPeptideFilterTableName) > 0
		Begin
		
			Set @CurrentLocation = 'Populate #TmpJobList using table "' + @JobPeptideFilterTableName + '"'
		
			Set @S = ''
			
			Set @S = @S + ' INSERT INTO #TmpJobList (Job, ResultType)'
			Set @S = @S + ' SELECT TAD.Job, TAD.ResultType'
			Set @S = @S + ' FROM [' + @JobPeptideFilterTableName + '] JPF'
			Set @S = @S +      ' INNER JOIN T_Analysis_Description TAD'
			Set @S = @S +        ' ON JPF.Job = TAD.Job'
			Set @S = @S + ' GROUP BY TAD.Job, TAD.ResultType'
			
			If @PreviewSql <> 0
				Print @S
				
			exec sp_executesql @S
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
		End
		Else
		Begin
			Set @CurrentLocation = 'Populate #TmpJobList using parameter @JobList'
			
			-- Parse the values in @JobList
			
			INSERT INTO #TmpJobList (Job)
			SELECT DISTINCT Value
			FROM dbo.udfParseDelimitedIntegerList(@JobList, ',')
			ORDER BY Value
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			
			
			Set @CurrentLocation = 'Validate the jobs in #TmpJobList'
			
			-- Populate the ResultType column in #TmpJobList
			UPDATE #TmpJobList
			Set ResultType = TAD.ResultType
			FROM #TmpJobList INNER JOIN 
			T_Analysis_Description TAD ON #TmpJobList.Job = TAD.Job
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			

			-- Remove invalid job types from #TmpJobList
			DELETE #TmpJobList
			WHERE ResultType Is Null
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			
			If @myRowCount <> 0
			Begin
				Set @message = 'Warning: removed ' + Convert(varchar(12), @myRowCount) + ' job(s) from #TmpJobList since they were not present in T_Analysis_Description'
				Print @message
				Set @message = ''
			End

			-- Look for any jobs that have the wrong value for ResultType			
			SET @message = ''
			
			SELECT @message = @message + ', ' + Convert(varchar(12), Job)
			FROM #TmpJobList
			WHERE NOT ResultType IN ('Peptide_Hit', 'XT_Peptide_Hit', 'IN_Peptide_Hit')
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			
			If @myRowCount <> 0
			Begin
				DELETE #TmpJobList
				WHERE ResultType IN ('Peptide_Hit', 'XT_Peptide_Hit', 'IN_Peptide_Hit')
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				Set @message = LTrim(SubString(@message, 2, Len(@message)))
				Set @message = 'Warning: removed ' + Convert(varchar(12), @myRowCount) + ' job(s) from #TmpJobList since they have an unsupported value for ResultType in T_Analysis_Description; Job(s): ' + @message

				Execute PostLogEntry 'Error', @message, 'PTExportPeptidesForJobs'
				Print @Message
				Set @message = ''
			End
			

		End
		
		--------------------------------------------------------------
		-- Make sure at least one valid job was specified
		--------------------------------------------------------------
		
		SELECT @JobMin = MIN(Job) - 1,
		       @JobCount = COUNT(*)
		FROM #TmpJobList

		If @JobCount = 0
		Begin
			Set @Message = 'Could not find any known, valid jobs in @JobList or @JobPeptideFilterTableName; valid result types are "Peptide_Hit", "XT_Peptide_Hit", and "IN_Peptide_Hit" and not "SIC"; in other words, use Sequest, XTandem, or Inspect job numbers, not MASIC'
			Set @myError = 20000
			Goto Done
		End

		--------------------------------------------------------------
		-- Determine which ResultTypes are present
		--------------------------------------------------------------

		Set @CurrentLocation = 'Determine which ResultTypes are present'

		Declare @PeptideHit tinyint
		Declare @XTPeptideHit tinyint
		Declare @InsPeptideHit tinyint
		
		If Exists (SELECT * FROM #TmpJobList WHERE ResultType = 'Peptide_Hit')
			Set @PeptideHit = 1
		Else
			Set @PeptideHit = 0

		If Exists (SELECT * FROM #TmpJobList WHERE ResultType = 'XT_Peptide_Hit')
			Set @XTPeptideHit = 1
		Else
			Set @XTPeptideHit = 0
		
		If Exists (SELECT * FROM #TmpJobList WHERE ResultType = 'IN_Peptide_Hit')
			Set @InsPeptideHit = 1
		Else
			Set @InsPeptideHit = 0	


		--------------------------------------------------------------
		-- Retrieve the data for each job, using temporary table #TmpPeptideStats
		-- as an interim processing table to reduce query complexity;
		-- place the results in temporary table #TmpPeptideStats_Results
		--------------------------------------------------------------

		Set @CurrentLocation = 'Create temporary tables'

		-- Create the temporary results table
		CREATE TABLE #TmpPeptideStats_Results (
			Job int NOT NULL ,
			Peptide_ID int NOT NULL ,			-- Will be a representative Peptide_ID if grouping is enabled
			Scan_Number int NULL ,
			Cleavage_State smallint NULL ,
			Mass_Tag_ID int NULL ,
			Peptide varchar(850) NULL ,
			Monoisotopic_Mass float NULL ,
			XCorr real NULL ,				-- Note: XTandem and Inspect data will populate this column with the estimated equivalent XCorr given the Hyperscore
					
			DeltaCn2 real NULL ,
			RankXC int NULL ,
			Charge_State smallint NULL,
			Discriminant real NULL ,
			Peptide_Prophet_Prob real NULL ,
			Elution_Time real NULL ,			-- Scan_Time_Peak_Apex
			Peak_SN real NULL ,					-- Peak_SN_Ratio
			Peak_Area float NULL ,				-- Peak_Area
			Spectra_Count int NULL				-- Number of spectra the peptide was seen in (will always be 1 if @GroupByPeptide = 0)
		)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		-- Create the interim processing table
		CREATE TABLE #TmpPeptideStats (
			Unique_Row_ID int NOT NULL Identity(1,1) ,
			Job int NOT NULL ,
			Peptide_ID int NOT NULL ,
			Scan_Number int NOT NULL ,
			Cleavage_State smallint NULL ,
			Mass_Tag_ID int NOT NULL ,
			Peptide varchar(850) ,
			Monoisotopic_Mass float NULL,
			XCorr real NULL ,

			DeltaCn2 real NULL ,
			RankXC int NULL ,
			Charge_State smallint NOT NULL ,

			Discriminant real NULL ,
			Peptide_Prophet_Prob real NULL ,

			Elution_Time real NULL ,		-- Scan_Time_Peak_Apex
			Peak_SN real NULL ,				-- Peak_SN_Ratio
			Peak_Area float NULL	,		-- Peak_Area

			UseValue tinyint NOT NULL Default 0
		)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		If @XTPeptideHit = 1
		Begin
			-- Add the XTandem-specific columns to the temporary tables
			
			ALTER TABLE #TmpPeptideStats_Results Add
				Hyperscore real NULL,
				Log_EValue real NULL

			ALTER TABLE #TmpPeptideStats Add
				Hyperscore real NULL,
				Log_EValue real NULL

		End
		
		If @InsPeptideHit = 1
		Begin
			-- Add the Inspect-specific columns to the temporary tables
			
			ALTER TABLE #TmpPeptideStats_Results Add
				MQScore real NULL,
				TotalPRMScore real NULL,
				FScore real NULL

			ALTER TABLE #TmpPeptideStats Add
				MQScore real NULL,
				TotalPRMScore real NULL,
				FScore real NULL

		End
		

		-- Add an index on Scan_Number and Job
		CREATE INDEX #IX_Tmp_PeptideStats_ScanNumberJob ON #TmpPeptideStats (Scan_Number, Job)

		-- Add an index on Mass_Tag_ID
		CREATE INDEX #IX_Tmp_PeptideStats_Mass_Tag_ID ON #TmpPeptideStats (Mass_Tag_ID)

		--------------------------------------------------------------
		-- Construct the commonly used strings
		--  First loop; construct text for Peptide_Hit jobs (@Iteration = 1)
		--  Second loop; construct text for XT_Peptide_Hit jobs (@Iteration = 2)
		--  Third loop; construct text for IN_Peptide_Hit jobs (@Iteration = 3)
		--------------------------------------------------------------
		Declare @Params nvarchar(2048)

		Declare @InsertSqlPeptideHit nvarchar(max)
		Declare @InsertSqlXTPeptideHit nvarchar(max)
		Declare @InsertSqlInsPeptideHit nvarchar(max)
		
		Declare @ColumnNameSqlPeptideHit nvarchar(2048)
		Declare @ColumnNameSqlXTPeptideHit nvarchar(2048)
		Declare @ColumnNameSqlInsPeptideHit nvarchar(2048)
		
		Declare @Iteration int
		
		Set @Iteration = 1
		While @Iteration <= 3
		Begin -- <a1>

			Set @CurrentLocation = 'Construct SQL; iteration = ' + Convert(varchar(12), @Iteration)

			-- Iteration 1 is Sequest jobs  (Peptide_Hit)
			-- Iteration 2 is X!Tandem jobs (XT_Peptide_Hit)
			-- Iteration 2 is Inspect jobs  (IN_Peptide_Hit)
		
			--------------------------------------------------------------
			-- Construct the @InsertSql text
			--------------------------------------------------------------
			Set @S = ''
			
			If @GroupByPeptide = 0
				Set @S = @S + ' INSERT INTO #TmpPeptideStats_Results ('
			Else
				Set @S = @S + ' INSERT INTO #TmpPeptideStats ('
			
			Set @S = @S +       ' Job, Peptide_ID, Scan_Number, Cleavage_State, Mass_Tag_ID, Peptide, Monoisotopic_Mass,'
			If @Iteration = 1
				Set @S = @S +   ' XCorr, DeltaCn2, RankXC, '
			If @Iteration = 2
				Set @S = @S +   ' XCorr, Hyperscore, Log_EValue, DeltaCn2, RankXC, '
			If @Iteration = 3
				Set @S = @S +   ' XCorr, MQScore, TotalPRMScore, FScore, DeltaCn2, RankXC, '

			Set @S = @S +   ' Charge_State, Discriminant, Peptide_Prophet_Prob, Elution_Time, Peak_SN, Peak_Area)'
			Set @S = @S + ' SELECT SourceQ.Job, SourceQ.Peptide_ID, SourceQ.Scan_Number, SourceQ.Cleavage_State_Max, '
			Set @S = @S +        ' SourceQ.Seq_ID, SourceQ.Peptide, SourceQ.Monoisotopic_Mass, '
			If @Iteration = 1
				Set @S = @S +    ' SS.XCorr, SS.DeltaCn2, SS.RankXC, '
			If @Iteration = 2
				Set @S = @S +    ' X.Normalized_Score, X.Hyperscore, X.Log_EValue, X.DeltaCn2, 1 AS RankXC, '
			If @Iteration = 3
				Set @S = @S +    ' I.Normalized_Score, I.MQScore, I.TotalPRMScore, I.FScore, I.DeltaScore, RankFScore AS RankXC, '

			Set @S = @S +        ' SourceQ.Charge_State, SD.DiscriminantScoreNorm, '
			Set @S = @S +        ' IsNull(SD.Peptide_Prophet_Probability, 0) AS Peptide_Prophet_Probability, '
			Set @S = @S +        ' SourceQ.Scan_Time_Peak_Apex, SourceQ.Peak_SN_Ratio, SourceQ.Peak_Area '
			Set @S = @S + ' FROM ('
			Set @S = @S +        ' SELECT Pep.Analysis_ID as Job, Pep.Scan_Number, MAX(PPM.Cleavage_State) AS Cleavage_State_Max, '
			Set @S = @S +               ' Pep.Seq_ID, Pep.Peptide, Seq.Monoisotopic_Mass, '
			Set @S = @S +               ' Pep.Charge_State, Pep.Scan_Time_Peak_Apex, Pep.Peak_SN_Ratio, Pep.Peak_Area, Pep.Peptide_ID '
			Set @S = @S +        ' FROM T_Peptides Pep INNER JOIN '
			Set @S = @S +             ' #TmpJobsCurrentBatch B On Pep.Analysis_ID = B.Job INNER JOIN '
			Set @S = @S +             ' T_Sequence Seq on Pep.Seq_ID = Seq.Seq_ID INNER JOIN '
			Set @S = @S +             ' T_Peptide_to_Protein_Map PPM ON Pep.Peptide_ID = PPM.Peptide_ID'
			If Len(@JobPeptideFilterTableName) > 0
				Set @S = @S +        ' INNER JOIN [' + @JobPeptideFilterTableName + '] JPF ON Pep.Analysis_ID = JPF.Job AND Pep.Peptide = JPF.Peptide '
			Set @S = @S +        ' WHERE PPM.Cleavage_State >= @MinimumCleavageState'
			Set @S = @S +        ' GROUP BY Pep.Analysis_ID, Pep.Scan_Number, '
			Set @S = @S +               ' Pep.Seq_ID, Pep.Peptide, Seq.Monoisotopic_Mass, '
			Set @S = @S +               ' Pep.Charge_State, Pep.Scan_Time_Peak_Apex, Pep.Peak_SN_Ratio, Pep.Peak_Area, Pep.Peptide_ID '
			
			Set @S = @S +      ' ) SourceQ INNER JOIN '
			If @Iteration = 1
				Set @S = @S +    ' T_Score_Sequest SS ON SourceQ.Peptide_ID = SS.Peptide_ID INNER JOIN '
			If @Iteration = 2
				Set @S = @S +    ' T_Score_XTandem X ON SourceQ.Peptide_ID = X.Peptide_ID INNER JOIN '
			If @Iteration = 3
				Set @S = @S +    ' T_Score_Inspect I ON SourceQ.Peptide_ID = I.Peptide_ID INNER JOIN '
			Set @S = @S +     ' T_Score_Discriminant SD ON SourceQ.Peptide_ID = SD.Peptide_ID '
			Set @S = @S + ' WHERE 1=1 AND'

			If @MinimumDiscriminantScore > 0
				Set @S = @S +   ' SD.DiscriminantScoreNorm >= @MinimumDiscriminantScore AND '

			-- Note: Do not filter X!Tandem data on Peptide Prophet 
			If @Iteration <> 2 And @MinimumPeptideProphetProbability > 0
				Set @S = @S +   ' IsNull(SD.Peptide_Prophet_Probability, 0) >= @MinimumPeptideProphetProbability AND '
			
			Set @S = @S +    '( '
			
			If @MinimumCleavageState < 2
				Set @S = @S +    '(SourceQ.Cleavage_State_Max = 2 AND '
				
			If @Iteration = 1
			Begin
				Set @S = @S +    '(SourceQ.Charge_State = 1 AND SS.DeltaCn2 >= @MinDelCn2 AND SS.XCorr >= @MinXCorrFullyTrypticCharge1 OR'
				Set @S = @S +    ' SourceQ.Charge_State = 2 AND SS.DeltaCn2 >= @MinDelCn2 AND SS.XCorr >= @MinXCorrFullyTrypticCharge2 OR'
				Set @S = @S +    ' SourceQ.Charge_State >= 3 AND SS.DeltaCn2 >= @MinDelCn2 AND SS.XCorr >= @MinXCorrFullyTrypticCharge3)'
			End

			If @Iteration = 2
			Begin
				Set @S = @S +    '(SourceQ.Charge_State = 1 AND X.DeltaCn2 >= @MinDelCn2 AND X.Normalized_Score >= @MinXCorrFullyTrypticCharge1 OR'
				Set @S = @S +    ' SourceQ.Charge_State = 2 AND X.DeltaCn2 >= @MinDelCn2 AND X.Normalized_Score >= @MinXCorrFullyTrypticCharge2 OR'
				Set @S = @S +    ' SourceQ.Charge_State >= 3 AND X.DeltaCn2 >= @MinDelCn2 AND X.Normalized_Score >= @MinXCorrFullyTrypticCharge3)'
			End

			If @Iteration = 3
			Begin
				Set @S = @S +    '(SourceQ.Charge_State = 1 AND I.DeltaScore >= @MinDelCn2 AND I.Normalized_Score >= @MinXCorrFullyTrypticCharge1 OR'
				Set @S = @S +    ' SourceQ.Charge_State = 2 AND I.DeltaScore >= @MinDelCn2 AND I.Normalized_Score >= @MinXCorrFullyTrypticCharge2 OR'
				Set @S = @S +    ' SourceQ.Charge_State >= 3 AND I.DeltaScore >= @MinDelCn2 AND I.Normalized_Score >= @MinXCorrFullyTrypticCharge3)'
			End

			If @MinimumCleavageState < 2
			Begin -- <b0>
				Set @S = @S +    ') OR (SourceQ.Cleavage_State_Max < 2 AND '

				If @Iteration = 1
				Begin
					Set @S = @S +    '(SourceQ.Charge_State = 1 AND SS.DeltaCn2 >= @MinDelCn2 AND SS.XCorr >= @MinXCorrPartiallyTrypticCharge1 OR'
					Set @S = @S +    ' SourceQ.Charge_State = 2 AND SS.DeltaCn2 >= @MinDelCn2 AND SS.XCorr >= @MinXCorrPartiallyTrypticCharge2 OR'
					Set @S = @S +    ' SourceQ.Charge_State >= 3 AND SS.DeltaCn2 >= @MinDelCn2 AND SS.XCorr >= @MinXCorrPartiallyTrypticCharge3)'
				End

				If @Iteration = 2
				Begin
					Set @S = @S +    '(SourceQ.Charge_State = 1 AND X.DeltaCn2 >= @MinDelCn2 AND X.Normalized_Score >= @MinXCorrPartiallyTrypticCharge1 OR'
					Set @S = @S +    ' SourceQ.Charge_State = 2 AND X.DeltaCn2 >= @MinDelCn2 AND X.Normalized_Score >= @MinXCorrPartiallyTrypticCharge2 OR'
					Set @S = @S +    ' SourceQ.Charge_State >= 3 AND X.DeltaCn2 >= @MinDelCn2 AND X.Normalized_Score >= @MinXCorrPartiallyTrypticCharge3)'
				End

				If @Iteration = 3
				Begin
					Set @S = @S +    '(SourceQ.Charge_State = 1 AND I.DeltaScore >= @MinDelCn2 AND I.Normalized_Score >= @MinXCorrPartiallyTrypticCharge1 OR'
					Set @S = @S +    ' SourceQ.Charge_State = 2 AND I.DeltaScore >= @MinDelCn2 AND I.Normalized_Score >= @MinXCorrPartiallyTrypticCharge2 OR'
					Set @S = @S +    ' SourceQ.Charge_State >= 3 AND I.DeltaScore >= @MinDelCn2 AND I.Normalized_Score >= @MinXCorrPartiallyTrypticCharge3)'
				End
				
				Set @S = @S +    ') '

			End -- </b0>
			
			Set @S = @S +  ' )'

			If @Iteration = 1
				Set @InsertSqlPeptideHit = @S
			If @Iteration = 2
				Set @InsertSqlXTPeptideHit = @S
			If @Iteration = 3
				Set @InsertSqlInsPeptideHit = @S
		
		
			--------------------------------------------------------------
			-- Construct the @ColumnNameSql text
			--------------------------------------------------------------

			Set @S = ''
			Set @S = @S +   ' Job, Peptide_ID, Scan_Number, Cleavage_State, Mass_Tag_ID, Peptide,'
			Set @S = @S +   ' Monoisotopic_Mass, XCorr,'
			If @Iteration = 2
				Set @S = @S +   ' Hyperscore, Log_Evalue,'
			If @Iteration = 3
				Set @S = @S +   ' MQScore, TotalPRMScore, FScore,'

			Set @S = @S +   ' DeltaCn2, RankXC, Charge_State,'
			Set @S = @S +   ' Discriminant, Peptide_Prophet_Prob,'
			Set @S = @S +   ' Elution_Time, Peak_SN, Peak_Area, Spectra_Count'

			If @Iteration = 1
				Set @ColumnNameSqlPeptideHit = @S
			If @Iteration = 2
				Set @ColumnNameSqlXTPeptideHit = @S
			If @Iteration = 3
				Set @ColumnNameSqlInsPeptideHit = @S
			
			Set @Iteration = @Iteration + 1
		End -- </a1>
		
		-- Params string for sp_ExecuteSql
		Set @Params = '@MinimumCleavageState tinyint, @MinimumDiscriminantScore real, @MinimumPeptideProphetProbability real, @MinDelCn2 real, @MinXCorrFullyTrypticCharge1 real, @MinXCorrFullyTrypticCharge2 real, @MinXCorrFullyTrypticCharge3 real, @MinXCorrPartiallyTrypticCharge1 real, @MinXCorrPartiallyTrypticCharge2 real, @MinXCorrPartiallyTrypticCharge3 real'
				
		--------------------------------------------------------------
		-- Obtain the data for each job in #TmpJobList and place in #TmpPeptideStats_Results
		--------------------------------------------------------------

		Set @CurrentLocation = 'Obtain data for each batch of jobs'
		
		Declare @JobIsPeptideHit tinyint
		Declare @JobIsXTPeptideHit tinyint
		Declare @JobIsInsPeptideHit tinyint

		Declare @JobsProcessed int
		Set @JobsProcessed = 0

		Declare @Continue int

		Set @Iteration = 1
		While @Iteration <= 3
		Begin -- <a2>

			-- Set @Continue to 1 for not, though it will be set to 0 if no appropriate jobs exist for this iteration
			Set @Continue = 1

			Set @JobIsPeptideHit = 0
			Set @JobIsXTPeptideHit = 0
			Set @JobIsInsPeptideHit = 0
			
			If @Iteration = 1
			Begin
				Set @ResultType = 'Peptide_Hit'
				Set @JobIsPeptideHit = 1

				If @PeptideHit = 0
					Set @Continue = 0		-- No Peptide_Hit jobs
			End

			If @Iteration = 2
			Begin
				Set @ResultType = 'XT_Peptide_Hit'
				Set @JobIsXTPeptideHit = 1

				If @XTPeptideHit = 0
					Set @Continue = 0		-- No XT_Peptide_Hit jobs
			End

			If @Iteration = 3
			Begin
				Set @ResultType = 'IN_Peptide_Hit'
				Set @JobIsInsPeptideHit = 1

				If @InsPeptideHit = 0
					Set @Continue = 0		-- No IN_Peptide_Hit jobs
			End

			If @Continue = 1
			Begin
				-- Initialize @JobMax
				Set @JobMax = 0
				SELECT @JobMax = MIN(Job)-1
				FROM #TmpJobList
			End
			
			While @Continue = 1
			Begin -- <b>
			
				Set @CurrentLocation = 'Get a batch of jobs with type ' + @ResultType
				
				-- Populate #TmpJobsCurrentBatch with the next batch of jobs
				TRUNCATE TABLE #TmpJobsCurrentBatch
				
				INSERT INTO #TmpJobsCurrentBatch (Job)
				SELECT TOP (@JobBatchSize) Job
				FROM #TmpJobList
				WHERE ResultType = @ResultType AND Job > @JobMax
				ORDER BY Job
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				If @myRowCount = 0 Or @myError <> 0
					Set @Continue = 0
				Else
				Begin -- <c>
					-- Found job(s) to process
					
					Set @JobMin = 0
					Set @JobMax = 0
					
					SELECT @JobMin = MIN(Job),
					       @JobMax = MAX(Job)
					FROM #TmpJobsCurrentBatch

					If @JobMin = @JobMax
						Set @JobDescription =  'job ' + Convert(varchar(12), @JobMin)
					Else
						Set @JobDescription =  'jobs ' + Convert(varchar(12), @JobMin) + ' to ' + Convert(varchar(12), @JobMax)
					
					Set @CurrentLocation = 'Obtain data for ' + @JobDescription
					
					If @PreviewSql <> 0
						Print @CurrentLocation
						
					-- Examine @ResultType to determine which Sql to use
					If @ResultType = 'Peptide_Hit'
						Set @JobIsPeptideHit = 1
					Else
						Set @JobIsPeptideHit = 0

					If @ResultType = 'XT_Peptide_Hit'
						Set @JobIsXTPeptideHit = 1
					Else
						Set @JobIsXTPeptideHit = 0

					If @ResultType = 'IN_Peptide_Hit'
						Set @JobIsInsPeptideHit = 1
					Else
						Set @JobIsInsPeptideHit = 0
											
					TRUNCATE TABLE #TmpPeptideStats

					-- If @GroupByPeptide is non-zero, then we now populate the interim processing table (#TmpPeptideStats) with the data for the jobs in this batch
					-- However, if @GroupByPeptide is zero, then we will now directly populate #TmpPeptideStats_Results
					-- 
					If @JobIsPeptideHit = 1
					Begin
						if @PreviewSql <> 0
							Print @InsertSqlPeptideHit
						else
							exec sp_ExecuteSql @InsertSqlPeptideHit, @Params, @MinimumCleavageState, @MinimumDiscriminantScore, @MinimumPeptideProphetProbability, @MinDelCn2, @MinXCorrFullyTrypticCharge1, @MinXCorrFullyTrypticCharge2, @MinXCorrFullyTrypticCharge3, @MinXCorrPartiallyTrypticCharge1, @MinXCorrPartiallyTrypticCharge2, @MinXCorrPartiallyTrypticCharge3
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error
					End
					
					If @JobIsXTPeptideHit = 1
					Begin
						if @PreviewSql <> 0
							Print @InsertSqlXTPeptideHit
						else
							exec sp_ExecuteSql @InsertSqlXTPeptideHit, @Params, @MinimumCleavageState, @MinimumDiscriminantScore, @MinimumPeptideProphetProbability, @MinDelCn2, @MinXCorrFullyTrypticCharge1, @MinXCorrFullyTrypticCharge2, @MinXCorrFullyTrypticCharge3, @MinXCorrPartiallyTrypticCharge1, @MinXCorrPartiallyTrypticCharge2, @MinXCorrPartiallyTrypticCharge3
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error
					End

					If @JobIsInsPeptideHit = 1
					Begin
						if @PreviewSql <> 0
							Print @InsertSqlInsPeptideHit
						else
							exec sp_ExecuteSql @InsertSqlInsPeptideHit, @Params, @MinimumCleavageState, @MinimumDiscriminantScore, @MinimumPeptideProphetProbability, @MinDelCn2, @MinXCorrFullyTrypticCharge1, @MinXCorrFullyTrypticCharge2, @MinXCorrFullyTrypticCharge3, @MinXCorrPartiallyTrypticCharge1, @MinXCorrPartiallyTrypticCharge2, @MinXCorrPartiallyTrypticCharge3
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error
					End
					
					If @PreviewSql <> 0
					Begin
						Print 'Params for previous Insert Into query: ' + @Params
						SELECT Job, 
								@MinimumCleavageState AS CleavageStateMinimum,
								@MinimumDiscriminantScore AS MinimumDiscriminantScore,
								@MinimumPeptideProphetProbability AS MinimumPeptideProphetProbability,
								@MinDelCn2 As MinDeltaCN, 
								@MinXCorrFullyTrypticCharge1 as MinXCorrCharge1, 
								@MinXCorrFullyTrypticCharge2 as MinXCorrCharge2, 
								@MinXCorrFullyTrypticCharge3 as MinXCorrCharge3, 
								@MinXCorrPartiallyTrypticCharge1 as MinXCorrPartiallyTrypticCharge1, 
								@MinXCorrPartiallyTrypticCharge2 as MinXCorrPartiallyTrypticCharge2, 
								@MinXCorrPartiallyTrypticCharge3 as MinXCorrPartiallyTrypticCharge3
						FROM #TmpJobsCurrentBatch
						ORDER BY Job

					End
				

					If @GroupByPeptide <> 0
					Begin -- <d>
						--------------------------------------------------------------
						-- Group By the metric indicated by @MaxValueSelectionMode, then populate #TmpPeptideStats_Results
						-- First, need to flag the row with the highest given value for each Mass_Tag_ID
						--------------------------------------------------------------

						Set @CurrentLocation = 'Flag rows with highest given value for each Mass_Tag_ID; ' + @JobDescription
						
						-- Define the Selection Field based on @MaxValueSelectionMode
						-- Default to use Peak_Area
						Set @SelectionField = 'Peak_Area'
						
						If @MaxValueSelectionMode = 0
							Set @SelectionField = 'Peak_Area'

						If @MaxValueSelectionMode = 1
							Set @SelectionField = 'Peak_SN'

						If @JobIsPeptideHit = 1
						Begin
							If @MaxValueSelectionMode >= 2
								Set @SelectionField = 'XCorr'
						End

						If @JobIsXTPeptideHit = 1
						Begin
							If @MaxValueSelectionMode = 2
								Set @SelectionField = 'Hyperscore'

							If @MaxValueSelectionMode >= 3
								Set @SelectionField = 'Log_Evalue'
						End
						
						If @JobIsInsPeptideHit = 1
						Begin
							If @MaxValueSelectionMode = 2
								Set @SelectionField = 'MQScore'

							If @MaxValueSelectionMode >= 3
								Set @SelectionField = 'FScore'
						End
					
			
						Set @S = ''
						Set @S = @S + ' UPDATE #TmpPeptideStats'
						Set @S = @S + ' SET UseValue = 1'
						Set @S = @S + ' FROM #TmpPeptideStats S'
						Set @S = @S +      ' INNER JOIN ( '
						Set @S = @S +          ' SELECT Unique_Row_ID, Job,'
						Set @S = @S +                 ' Row_Number() OVER ( PARTITION BY Job, Mass_Tag_ID '
						If @GroupByChargeState <> 0
							Set @S = @S +			                              ', Charge_State'
						Set @S = @S +			                          ' ORDER BY ' + @SelectionField + ' DESC, XCorr DESC, Scan_Number ) AS ScoreRank'
						Set @S = @S +          ' FROM #TmpPeptideStats '
						Set @S = @S +    ' ) LookupQ ON S.Job = LookupQ.Job AND S.Unique_Row_ID = LookupQ.Unique_Row_ID'
						Set @S = @S + ' WHERE ScoreRank = 1'
						
						If @PreviewSql <> 0
							Print @S
						Else
							exec sp_ExecuteSql @S
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error							


						--------------------------------------------------------------
						-- Append the desired data to #TmpPeptideStats_Results
						-- We have to use dynamic SQL here because the table may not contain
						--  columns Hyperscore or Log_Evalue
						--------------------------------------------------------------

						Set @CurrentLocation = 'Append data to #TmpPeptideStats_Results for ' + @JobDescription
						
						Set @S = ''
						Set @S = @S + ' INSERT INTO #TmpPeptideStats_Results ('

						If @JobIsPeptideHit = 1
							Set @S = @S + @ColumnNameSqlPeptideHit

						If @JobIsXTPeptideHit = 1
							Set @S = @S + @ColumnNameSqlXTPeptideHit

						If @JobIsInsPeptideHit = 1
							Set @S = @S + @ColumnNameSqlInsPeptideHit
						
						
						Set @S = @S + ' )'
						Set @S = @S + ' SELECT S.Job, S.Peptide_ID, S.Scan_Number,'
						Set @S = @S +   ' S.Cleavage_State, S.Mass_Tag_ID, S.Peptide,'
						Set @S = @S +   ' S.Monoisotopic_Mass, S.XCorr,'
						
						If @JobIsXTPeptideHit = 1
							Set @S = @S +   ' S.Hyperscore,S.Log_Evalue,'
						If @JobIsInsPeptideHit = 1
							Set @S = @S + ' S.MQScore, S.TotalPRMScore, S.FScore,'

						Set @S = @S +   ' S.DeltaCn2, S.RankXC, S.Charge_State,'
						Set @S = @S +   ' S.Discriminant, S.Peptide_Prophet_Prob,'
						Set @S = @S +   ' S.Elution_Time, S.Peak_SN, S.Peak_Area, 1 AS Spectra_Count'
						
						Set @S = @S + ' FROM #TmpPeptideStats S '
						Set @S = @S + ' WHERE S.UseValue = 1'
						Set @S = @S + ' ORDER BY S.Job, S.XCorr DESC, S.Mass_Tag_ID'

						If @PreviewSql <> 0
							Print @S
						Else
							exec sp_ExecuteSql @S
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error	


						If @ReportHighestScoreStatsInJob <> 0
						Begin -- <e>
							--------------------------------------------------------------
							-- Update the data in #TmpPeptideStats_Results for this batch to reflect the maximum scores for each peptide
							-- This is only valid @MaxValueSelectionMode was Peak_Area or Peak_SN_Ratio
							--------------------------------------------------------------
							
							Set @CurrentLocation = 'Lookup the maximum scores for each peptide for ' + @JobDescription
							
							If @JobIsPeptideHit = 1
								Set @SelectionField = 'XCorr'

							If @JobIsXTPeptideHit = 1
								Set @SelectionField = 'Hyperscore'
						
							if @JobIsInsPeptideHit = 1
								Set @SelectionField = 'MQScore'
							
							If @MaxValueSelectionMode <= 1
							Begin -- <f>
								
								Set @S = ''
								Set @S = @S + ' UPDATE #TmpPeptideStats_Results'
								Set @S = @S + ' SET Peptide_ID = MaxValuesQ.Peptide_ID,'
								Set @S = @S +     ' XCorr = MaxValuesQ.XCorr,'
								Set @S = @S +     ' DeltaCn2 = MaxValuesQ.DeltaCn2,'
								Set @S = @S +     ' RankXC = MaxValuesQ.RankXC,'
								Set @S = @S +     ' Charge_State = MaxValuesQ.Charge_State,'
								Set @S = @S +     ' Scan_Number = MaxValuesQ.Scan_Number'
								If @JobIsXTPeptideHit = 1
								Begin
									Set @S = @S + ' , Hyperscore = MaxValuesQ.Hyperscore'
									Set @S = @S + ' , Log_EValue = MaxValuesQ.Log_EValue'
								End
								
								If @JobIsInsPeptideHit = 1
								Begin
									Set @S = @S + ' , MQScore = MaxValuesQ.MQScore'
									Set @S = @S + ' , TotalPRMScore = MaxValuesQ.TotalPRMScore'
									Set @S = @S + ' , FScore = MaxValuesQ.FScore'
								End
								
								Set @S = @S + ' FROM #TmpPeptideStats_Results Target INNER JOIN'
								Set @S = @S + ' ( SELECT S.Job, S.Peptide_ID, S.Mass_Tag_ID, S.XCorr, '
								Set @S = @S +          ' S.DeltaCn2, S.RankXC, S.Charge_State, S.Scan_Number'
								If @JobIsXTPeptideHit = 1
									Set @S = @S +    ' , S.Hyperscore, S.Log_EValue'

								If @JobIsInsPeptideHit = 1
									Set @S = @S +    ' , S.MQScore, S.TotalPRMScore, S.FScore'
									
								Set @S = @S +   ' FROM #TmpPeptideStats S INNER JOIN'
								Set @S = @S +      ' ( SELECT MIN(S.Unique_Row_ID) AS Unique_Row_ID_Min'
								Set @S = @S +        ' FROM #TmpPeptideStats S INNER JOIN'
								Set @S = @S +         ' ( SELECT Job, Mass_Tag_ID, MAX(' + @SelectionField + ') AS Value_Max'
								If @GroupByChargeState <> 0
									Set @S = @S +			  ', Charge_State'
								Set @S = @S +           ' FROM #TmpPeptideStats'
								Set @S = @S +     ' GROUP BY Job, Mass_Tag_ID'
								If @GroupByChargeState <> 0
									Set @S = @S +				', Charge_State'
								Set @S = @S +         ' ) LookupQ ON'
								Set @S = @S +         ' S.Job = LookupQ.Job AND'
								Set @S = @S +         ' S.Mass_Tag_ID = LookupQ.Mass_Tag_ID AND'
								If @GroupByChargeState <> 0
									Set @S = @S +     ' S.Charge_State = LookupQ.Charge_State AND'
								Set @S = @S +         ' S.' + @SelectionField + ' = LookupQ.Value_Max'
								Set @S = @S +         ' GROUP BY S.Mass_Tag_ID'
								If @GroupByChargeState <> 0
									Set @S = @S +				', S.Charge_State'
								Set @S = @S +      ' ) UniqueRowQ ON'
								Set @S = @S +      ' S.Unique_Row_ID = UniqueRowQ.Unique_Row_ID_Min'
								Set @S = @S +   ' ) MaxValuesQ ON Target.Mass_Tag_ID = MaxValuesQ.Mass_Tag_ID AND Target.Job = MaxValuesQ.Job'
								If @GroupByChargeState <> 0
									Set @S = @S +   ' AND Target.Charge_State = MaxValuesQ.Charge_State'
																	
								If @PreviewSql <> 0
									Print @S
								Else
									exec sp_ExecuteSql @S
								--
								SELECT @myRowCount = @@rowcount, @myError = @@error
							End -- </f>

							Set @S = ''
							Set @S = @S + ' UPDATE #TmpPeptideStats_Results'
							Set @S = @S + ' SET Discriminant = MaxValuesQ.Discriminant,'
							Set @S = @S +   ' Peptide_Prophet_Prob = MaxValuesQ.Peptide_Prophet_Prob'
							Set @S = @S + ' FROM #TmpPeptideStats_Results Target INNER JOIN'
							Set @S = @S + ' ( SELECT Job, Mass_Tag_ID,'
							Set @S = @S +          ' MAX(Discriminant) AS Discriminant,'
							Set @S = @S +          ' MAX(Peptide_Prophet_Prob) AS Peptide_Prophet_Prob'
							If @GroupByChargeState <> 0
								Set @S = @S +    ', Charge_State'
							Set @S = @S +   ' FROM #TmpPeptideStats'
							Set @S = @S +   ' GROUP BY Job, Mass_Tag_ID'
							If @GroupByChargeState <> 0
								Set @S = @S +         ', Charge_State'
							Set @S = @S + ' ) MaxValuesQ ON Target.Mass_Tag_ID = MaxValuesQ.Mass_Tag_ID AND Target.Job = MaxValuesQ.Job'
							If @GroupByChargeState <> 0
								Set @S = @S + ' AND Target.Charge_State = MaxValuesQ.Charge_State'
												
							If @PreviewSql <> 0
								Print @S
							Else
								exec sp_ExecuteSql @S
							--
							SELECT @myRowCount = @@rowcount, @myError = @@error

						End -- </e>
					
					End -- </d>

					--------------------------------------------------------------
					-- Determine the spectral count values for each job newly added to #TmpPeptideStats_Results
					--------------------------------------------------------------
					
					Set @CurrentLocation = 'Determine spectra counts for ' + @JobDescription
					
					Set @S = ''
					Set @S = @S + ' UPDATE #TmpPeptideStats_Results '
					Set @S = @S +        ' SET Spectra_Count = LookupQ.Spectra_Count'
					Set @S = @S + ' FROM #TmpPeptideStats_Results Target INNER JOIN ('
					
					Set @S = @S +     ' SELECT Pep.Analysis_ID AS Job, Pep.Seq_ID AS Mass_Tag_ID,'
					If @GroupByChargeState <> 0
						Set @S = @S +        ' Pep.Charge_State,'
					Set @S = @S +            ' COUNT(*) AS Spectra_Count'
					Set @S = @S +     ' FROM T_Peptides Pep INNER JOIN '
					Set @S = @S +          ' (SELECT DISTINCT R.Job, R.Mass_Tag_ID'
					If @GroupByChargeState <> 0
						Set @S = @S +               ', Charge_State'
					Set @S = @S +          '  FROM #TmpPeptideStats_Results R INNER JOIN '
					Set @S = @S +                ' #TmpJobsCurrentBatch B ON R.Job = B.Job'
					Set @S = @S +          ' ) S ON Pep.Analysis_ID = S.Job AND Pep.Seq_ID = S.Mass_Tag_ID'
					If @GroupByChargeState <> 0
						Set @S = @S +      ' AND Pep.Charge_State = S.Charge_State'
					Set @S = @S +     ' GROUP BY Pep.Analysis_ID, Pep.Seq_ID'
					If @GroupByChargeState <> 0
						Set @S = @S +    ' ,Pep.Charge_State'
					Set @S = @S +     ') LookupQ ON Target.Job = LookupQ.Job AND Target.Mass_Tag_ID = LookupQ.Mass_Tag_ID'
					If @GroupByChargeState <> 0
						Set @S = @S +    ' AND Target.Charge_State = LookupQ.Charge_State'
					
					If @PreviewSql <> 0
						Print @S
					Else
						exec sp_ExecuteSql @S
					--
					SELECT @myRowCount = @@rowcount, @myError = @@error	
					
				End -- </c>
				
				If @PreviewSql <> 0
					Set @Continue = 0
				
				Set @JobsProcessed = @JobsProcessed + 1
				
				If @MaxJobsToProcess > 0 And @JobsProcessed >= @MaxJobsToProcess
					Set @Continue = 0
					
			End -- </b>
			
			Set @Iteration = @Iteration + 1
		End -- </a2>

		--------------------------------------------------------------
		-- Query #TmpPeptideStats_Results to obtain the data and/or count the rows
		--------------------------------------------------------------

		Set @CurrentLocation = 'Query #TmpPeptideStats_Results to obtain the data and/or count the rows'
		
		If @XTPeptideHit = 1
			Set @S = 'SELECT ' + @ColumnNameSqlXTPeptideHit
		Else
		Begin
			If @InsPeptideHit = 1
				Set @S = 'SELECT ' + @ColumnNameSqlInsPeptideHit
			Else
				Set @S = 'SELECT ' + @ColumnNameSqlPeptideHit
		End

		Set @S = @S + '	FROM #TmpPeptideStats_Results'
		Set @S = @S + '	ORDER BY Job, Mass_Tag_ID, XCorr DESC'

		If @PreviewSql <> 0
			Print @S
		Else
		Begin
			
			If @ReturnPeptideTable <> 0
			Begin
				-- Return the contents of #TmpPeptideStats_Results
				
				exec sp_ExecuteSql @S
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error							

				Set @PeptideCount = @myRowCount
			End
			Else
			Begin
				-- Determine the number of rows that would be returned
				
				SELECT @PeptideCount = COUNT(*) 
				FROM #TmpPeptideStats_Results
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error						
			End
			
			If @ReturnMTTable <> 0 OR @ReturnProteinTable <> 0 Or @ReturnProteinMapTable <> 0 OR @ReturnPeptideToProteinMapTable <> 0
			Begin
				-- Return the AMT tag and/or protein details

				Exec @myError = PTExportAMTTables @ReturnMTTable, @ReturnProteinTable, @ReturnProteinMapTable, @ReturnPeptideToProteinMapTable, @message= @message output

			End

			If @ReturnJobInfoTable <> 0
			Begin
				SELECT TAD.Job, TAD.Dataset, TAD.Dataset_ID,
				       DS.Created_DMS AS Dataset_Created_DMS,
				       DS.Acq_Time_Start AS Dataset_Acq_Time_Start,
				       DS.Acq_Time_End AS Dataset_Acq_Time_End,
				       DS.Scan_Count AS Dataset_Scan_Count,
				       TAD.Experiment, TAD.Campaign, TAD.Experiment_Organism,
				       TAD.Instrument_Class, TAD.Instrument, TAD.Analysis_Tool,
				       TAD.Parameter_File_Name, TAD.Settings_File_Name, TAD.Organism_DB_Name,
				       TAD.Protein_Collection_List, TAD.Protein_Options_List,
				       TAD.Vol_Client + TAD.Dataset_Folder AS Storage_Path_Archive,
				       TAD.Vol_Server + TAD.Dataset_Folder AS Storage_Path_Local,
				       TAD.Results_Folder, TAD.Completed, TAD.ResultType,
				       TAD.Separation_Sys_Type, TAD.PreDigest_Internal_Std,
				       TAD.PostDigest_Internal_Std, TAD.Dataset_Internal_Std,
				       TAD.Enzyme_ID, TAD.Labelling,
				       TAD.Created AS Job_Created_DB, 
				       TAD.Last_Affected AS Job_Last_Affected,
				       TAD.RowCount_Loaded,
				       TAD.ScanTime_NET_Slope, TAD.ScanTime_NET_Intercept, 
				       TAD.ScanTime_NET_RSquared, TAD.ScanTime_NET_Fit,
				       TAD.Regression_Order, TAD.Regression_Filtered_Data_Count
				FROM T_Analysis_Description TAD
				     INNER JOIN #TmpJobList J
				       ON TAD.Job = J.Job
				     INNER JOIN T_Datasets DS
				   ON TAD.Dataset_ID = DS.Dataset_ID
				ORDER BY Job
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error							

			End
			
			-- Count the number of AMT tags in #TmpPeptideStats_Results
			SELECT @AMTCount = COUNT(DISTINCT Mass_Tag_ID)
			FROM #TmpPeptideStats_Results
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
		End

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'PTExportPeptidesForJobs')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output
		Goto DoneSkipLog
	End Catch

Done:
	-----------------------------------------------------------
	-- Done processing
	-----------------------------------------------------------
		
	If @myError <> 0 
	Begin
		Execute PostLogEntry 'Error', @message, 'PTExportPeptidesForJobs'
		Print @message
	End
				

DoneSkipLog:	
	Return @myError


GO
GRANT EXECUTE ON [dbo].[PTExportPeptidesForJobs] TO [DMS_SP_User] AS [dbo]
GO
