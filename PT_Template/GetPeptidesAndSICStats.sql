/****** Object:  StoredProcedure [dbo].[GetPeptidesAndSICStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.GetPeptidesAndSICStats
/****************************************************
**
**	Desc: 
**		Returns a list of peptides and SIC stats for the
**		given list of Sequest jobs
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	09/27/2005
**			12/16/2005 mem - Now returning additional MASIC columns
**						   - Added parameters @GroupByPeptide, @MaxValueSelectionMode, @MinXCorrFullyTrypticCharge1, @MinXCorrFullyTrypticCharge2, @MinXCorrFullyTrypticCharge3, and @MinDeltaCn
**			01/20/2006 mem - Now returning the Monoisotopic_Mass and Parent_Ion_MZ for each peptide
**			03/17/2006 mem - Updated to work with XTandem results
**			09/15/2006 mem - Added parameters @MinXCorrPartiallyTrypticCharge1, @MinXCorrPartiallyTrypticCharge2, and @MinXCorrPartiallyTrypticCharge3
**						   - Renamed parameters @MinXCorrCharge1, @MinXCorrCharge2, and @MinXCorrCharge3 to @MinXCorrFullyTrypticCharge1, @MinXCorrFullyTrypticCharge2, and @MinXCorrFullyTrypticCharge3
**			02/03/2007 mem - Removed invalid Group By on XCorr when flagging the row with the highest value for each Seq_ID, as specified by @MaxValueSelectionMode
**						   - Added parameter @ReportHighestScoreStatsInJob
**			02/11/2007 mem - Added parameter @GroupByChargeState
**			05/15/2007 mem - Added parameter @JobPeptideFilterTableName
**			01/02/2008 mem - Now returning the MS/MS Scan number that corresponds to the area returned for the given peptide
**			06/30/2008 mem - Added parameter @JobScanRequiredTableName
**			09/08/2008 mem - Updated to allow @JobList to be blank if @JobPeptideFilterTableName is defined
**			09/12/2008 mem - Added parameter @MaxJobsToProcess; useful for debugging
**			10/21/2008 mem - Added support for Inspect results (type IN_Peptide_Hit)
**			08/23/2011 mem - Added support for MSGFDB results (type MSG_Peptide_Hit)
**						   - Now returning MSGF_SpecProb
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			12/04/2012 mem - Added support for MSAlign results (type MSA_Peptide_Hit)
**			12/05/2012 mem - Now using tblPeptideHitResultTypes to determine the valid Peptide_Hit result types
**			03/25/2013 mem - Removed nine MASIC SICResults columns
**    
*****************************************************/
(
	@JobList varchar(max),							-- Comma separated list of Sequest job numbers
	@CleavageStateMinimum tinyint = 2,
	@GroupByPeptide tinyint = 1,					-- If 1, then group by peptide, returning the max value (specified by @MaxValueSelectionMode) for each sequence in each job
	@GroupByChargeState tinyint = 0,				-- If 1, then reports separate values for each charge state; only valid if @GroupByPeptide = 1
	@MaxValueSelectionMode tinyint = 0,				-- 0 means use Peak_Area, 1 means use Peak_SN_Ratio, 2 means use StatMoments_Area, 3 means use XCorr or Hyperscore or MQScore or MSGFDB_SpecProb or MSAlign_PValue, 4 means Log_Evalue (only applicable for XTandem) or FScore (only applicable for Inspect)
	@ReportHighestScoreStatsInJob tinyint = 1,		-- Only applicable if @GroupByPeptide = 1 and if @MaxValueSelectionMode is not 3 or 4; when 1, then finds the entry with the max area or SN_Ratio, but updates the Sequest/X!Tandem score stats to reflect the highest scores in the analysis job
	@MinXCorrFullyTrypticCharge1 real = 1.9,		-- Only used for fully tryptic peptides
	@MinXCorrFullyTrypticCharge2 real = 2.2,		-- Only used for fully tryptic peptides
	@MinXCorrFullyTrypticCharge3 real = 3.75,		-- Only used for fully tryptic peptides
	@MinDeltaCn real = 0.1,							-- This is actually DeltaCn2
	@MinXCorrPartiallyTrypticCharge1 real = 4.0,		-- Only used if @CleavageStateMinimum is < 2
	@MinXCorrPartiallyTrypticCharge2 real = 4.3,		-- Only used if @CleavageStateMinimum is < 2
	@MinXCorrPartiallyTrypticCharge3 real = 4.7,		-- Only used if @CleavageStateMinimum is < 2
	@JobPeptideFilterTableName varchar(128) = '',		-- If provided, then will filter the results to only include peptides defined in this table; the table must have fields Job and Peptide and the peptides must be in the format A.BCDEFGH.I
	@JobScanRequiredTableName varchar(128) = '',		-- If provided, then will guarantee that the results include the scan numbers specified in this table; the table must have fields Job and Scan_Number and the jobs must be Sequest job numbers.  If this DB has no record of peptides for any of the specified scans, then the data will still be returned, but null values will be reported for the peptide sequence and the various scores; this table can be the same as @JobPeptideFilterTableName, as long as the table contains columns Job, Peptide, and Scan_Number
	@MaxJobsToProcess int = 0,						-- Maximum number of jobs to process; leave at 0 to process all jobs defined in @JobList or @JobPeptideFilterTableName
	@PreviewSql tinyint = 0,
	@message varchar(512) = '' output
)
As
	Set NoCount On
	
	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Declare @result int

	Declare @UseValueMinimum tinyint
	Set @UseValueMinimum = 0

	Declare @SelectionField varchar(32)
	Declare @SelectionAggregator varchar(3)

	Declare @Dataset varchar(256)
	Declare @S nvarchar(max)

	--------------------------------------------------------------
	-- Validate the inputs
	--------------------------------------------------------------

	Set @JobList = IsNull(@JobList, '')
	
	Set @CleavageStateMinimum = IsNull(@CleavageStateMinimum, 2)
	Set @GroupByPeptide = IsNull(@GroupByPeptide, 1)
	Set @GroupByChargeState = IsNull(@GroupByChargeState, 0)

	Set @MaxValueSelectionMode = IsNull(@MaxValueSelectionMode, 0)
	If @MaxValueSelectionMode < 0
		Set @MaxValueSelectionMode = 0
	if @MaxValueSelectionMode > 4
		Set @MaxValueSelectionMode = 4

	Set @ReportHighestScoreStatsInJob = IsNull(@ReportHighestScoreStatsInJob, 1)
	
	Set @MinXCorrFullyTrypticCharge1 = IsNull(@MinXCorrFullyTrypticCharge1, 1.9)
	Set @MinXCorrFullyTrypticCharge2 = IsNull(@MinXCorrFullyTrypticCharge2, 2.2)
	Set @MinXCorrFullyTrypticCharge3 = IsNull(@MinXCorrFullyTrypticCharge3, 3.75)
	Set @MinDeltaCn = IsNull(@MinDeltaCn, 0.1)

	Set @MinXCorrPartiallyTrypticCharge1 = IsNull(@MinXCorrPartiallyTrypticCharge1, 4.0)
	Set @MinXCorrPartiallyTrypticCharge2 = IsNull(@MinXCorrPartiallyTrypticCharge2, 4.3)
	Set @MinXCorrPartiallyTrypticCharge3 = IsNull(@MinXCorrPartiallyTrypticCharge3, 4.7)

	Set @JobPeptideFilterTableName = LTrim(RTrim(IsNull(@JobPeptideFilterTableName, '')))
	Set @JobScanRequiredTableName = LTrim(RTrim(IsNull(@JobScanRequiredTableName, '')))
	
	Set @MaxJobsToProcess = IsNull(@MaxJobsToProcess, 0)
	Set @PreviewSql = IsNull(@PreviewSql, 0)
	
	Set @message = ''


	--------------------------------------------------------------
	-- Parse out each of the jobs in @JobList
	-- Populate #TmpJobList with the job numbers and Result_Type of each job
	-- If @JobList is empty, but @JobPeptideFilterTableName is defined, then examine
	--  @JobPeptideFilterTableName to determine the job numbers
	--------------------------------------------------------------

	CREATE TABLE #TmpJobList (
		Job int NOT NULL ,
		ResultType varchar(32) NULL
	)

	-- Add a clustered index to #TmpJobList
	CREATE CLUSTERED INDEX IX_TmpJobList ON #TmpJobList(Job)
	
	If Len(@JobList) = 0 And Len(@JobPeptideFilterTableName) > 0
	Begin
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
		
		-- Make sure @JobList ends in a comma
		Set @JobList = LTrim(RTrim(@JobList)) + ','
		
		Declare @Job int
		Declare @SICJob int
		Declare @ResultType varchar(32)
		
		Declare @CurrentJob varchar(1024)
		Declare @CommaLoc int
		Declare @JobCount int
		Set @JobCount = 0

		Set @CommaLoc = CharIndex(',', @JobList)
		While @CommaLoc >= 1
		Begin
			Set @CurrentJob = LTrim(Left(@JobList, @CommaLoc-1))
			Set @JobList = SubString(@JobList, @CommaLoc+1, Len(@JobList))
		
			If IsNumeric(@CurrentJob) = 1
			Begin
				Set @Job = Convert(int, @CurrentJob)
				
				If Not Exists (SELECT Job FROM #TmpJobList WHERE Job = @Job)
				Begin
					INSERT INTO #TmpJobList
					SELECT Job, ResultType
					FROM T_Analysis_Description
					WHERE Job = @Job AND ResultType IN (SELECT ResultType FROM dbo.tblPeptideHitResultTypes())
					--
					SELECT @myRowCount = @@rowcount, @myError = @@error

					If @myRowCount > 0
						Set @JobCount = @JobCount + 1
				End
			End	

			Set @CommaLoc = CharIndex(',', @JobList)
		End
	End
	
	--------------------------------------------------------------
	-- Make sure at least one valid job was specified
	--------------------------------------------------------------
	
	SELECT @Job = MIN(Job)-1, 
		   @JobCount = COUNT(*)
	FROM #TmpJobList

	If @JobCount = 0
	Begin
		Set @Message = 'Could not find any known, valid jobs in @JobList or @JobPeptideFilterTableName; valid result types are "Peptide_Hit", "XT_Peptide_Hit", "IN_Peptide_Hit","MSG_Peptide_Hit", and "MSA_Peptide_Hit" but not "SIC"; in other words, use Sequest, XTandem, Inspect, MSGF-DB (MSGF+), or MSAlign job numbers, not MASIC'
		Set @myError = 20000
		Goto Done
	End

	--------------------------------------------------------------
	-- Determine which ResultTypes are present
	--------------------------------------------------------------

	Declare @PeptideHit tinyint = 0
	Declare @XTPeptideHit tinyint = 0
	Declare @InsPeptideHit tinyint = 0
	Declare @MsgPeptideHit tinyint = 0
	Declare @MsaPeptideHit tinyint = 0
	
	If Exists (SELECT Job FROM #TmpJobList WHERE ResultType = 'Peptide_Hit')
		Set @PeptideHit = 1

	If Exists (SELECT Job FROM #TmpJobList WHERE ResultType = 'XT_Peptide_Hit')
		Set @XTPeptideHit = 1
	
	If Exists (SELECT Job FROM #TmpJobList WHERE ResultType = 'IN_Peptide_Hit')
		Set @InsPeptideHit = 1

	If Exists (SELECT Job FROM #TmpJobList WHERE ResultType = 'MSG_Peptide_Hit')
		Set @MsgPeptideHit = 1

	If Exists (SELECT Job FROM #TmpJobList WHERE ResultType = 'MSA_Peptide_Hit')
		Set @MsaPeptideHit = 1

	--------------------------------------------------------------
	-- Retrieve the data for each job, using temporary table #TmpPeptidesAndSICStats
	-- as an interim processing table to reduce query complexity and
	-- placing the results in temporary table #TmpPeptidesAndSICStats_Results
	--------------------------------------------------------------

	-- Create the temporary results table
	CREATE TABLE #TmpPeptidesAndSICStats_Results (
		SIC_Job int NOT NULL ,
		Job int NOT NULL ,
		Dataset varchar(128) NOT NULL ,
		Reference varchar(255) NULL ,
		Cleavage_State tinyint NULL,
		RankHit smallint NULL ,
		DelM_PPM real NULL ,

		Seq_ID int NULL ,
		Peptide varchar(850) NULL,
		Monoisotopic_Mass float NULL,
		XCorr real NULL ,				-- Note: XTandem and Inspect data will populate this column with the estimated equivalent XCorr given the Hyperscore
				
		DeltaCn2 real NULL ,
		Charge_State smallint NULL,
		Discriminant real NULL ,
		Peptide_Prophet_Prob real NULL ,
		MSGF_SpecProb real NULL ,
		Optimal_Scan_Number real NULL ,
		Elution_Time real NULL,
		Intensity float NULL,
		SN real NULL,
		FWHM int NULL,
		Area float NULL,
		
		Parent_Ion_Intensity real NULL,
		Parent_Ion_MZ real NULL,
		/*
		 * No longer tracked by this DB: 
			Peak_Baseline_Noise_Level real NULL,
			Peak_Baseline_Noise_StDev real NULL,
			Peak_Baseline_Points_Used smallint NULL,
			
			StatMoments_Area real NULL,
			CenterOfMass_Scan int NULL,
			Peak_StDev real NULL,
			Peak_Skew real NULL,
			Peak_KSStat real NULL,
			StatMoments_DataCount_Used smallint NULL,
		*/
		MSMS_Scan_Number int NULL
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	-- Create the interim processing table
	CREATE TABLE #TmpPeptidesAndSICStats (
		Unique_Row_ID int NOT NULL Identity(1,1),
		SIC_Job int NOT NULL ,
		Job int NOT NULL ,
		Dataset_ID int NOT NULL ,
		Dataset varchar(128) NOT NULL ,
		Reference varchar(255) NOT NULL ,
		Seq_ID int NOT NULL ,
		Peptide varchar(850) ,
		Monoisotopic_Mass float NULL,
		DiscriminantScoreNorm real NULL ,
		Peptide_Prophet_Probability real NULL ,
		MSGF_SpecProb real NULL ,
		XCorr real NULL ,
	
		DeltaCn2 real NULL ,
		Charge_State smallint NOT NULL ,
		Scan_Number int NOT NULL,
		Cleavage_State tinyint NULL,
		RankHit smallint NULL ,
		DelM_PPM real NULL ,

		Optimal_Peak_Apex_Scan_Number int NULL,
		Peak_Intensity float NULL,
		Parent_Ion_MZ real NULL,
		Peak_SN_Ratio real NULL,
		FWHM_In_Scans int NULL,
		Peak_Area float NULL,

		Parent_Ion_Intensity real NULL,
		/*
		 * No longer tracked by this DB: 				
			Peak_Baseline_Noise_Level real NULL,
			Peak_Baseline_Noise_StDev real NULL,
			Peak_Baseline_Points_Used smallint NULL,

			StatMoments_Area real NULL,
			CenterOfMass_Scan int NULL,
			Peak_StDev real NULL,
			Peak_Skew real NULL,
			Peak_KSStat real NULL,
			StatMoments_DataCount_Used smallint NULL,
		*/
		UseValue tinyint NOT NULL Default 0
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	If @XTPeptideHit = 1
	Begin
		-- Add the XTandem-specific columns to the temporary tables
		
		ALTER TABLE #TmpPeptidesAndSICStats_Results Add
			Hyperscore real NULL,
			Log_EValue real NULL

		ALTER TABLE #TmpPeptidesAndSICStats Add
			Hyperscore real NULL,
			Log_EValue real NULL

	End
	
	If @InsPeptideHit = 1
	Begin
		-- Add the Inspect-specific columns to the temporary tables
		
		ALTER TABLE #TmpPeptidesAndSICStats_Results Add
			MQScore real NULL,
			TotalPRMScore real NULL,
			FScore real NULL

		ALTER TABLE #TmpPeptidesAndSICStats Add
			MQScore real NULL,
			TotalPRMScore real NULL,
			FScore real NULL

	End
	
	If @MsgPeptideHit = 1
	Begin
		-- Add the MSGF-DB specific columns to the temporary tables
		
		ALTER TABLE #TmpPeptidesAndSICStats_Results Add
			MSGFDB_DeNovoScore real NULL,
			MSGFDB_MSGFScore real NULL,
			MSGFDB_SpecProb real NULL,
			MSGFDB_PValue real NULL,
			MSGFDB_FDR real NULL,
			MSGFDB_PepFDR real NULL

		ALTER TABLE #TmpPeptidesAndSICStats Add
			MSGFDB_DeNovoScore real NULL,
			MSGFDB_MSGFScore real NULL,
			MSGFDB_SpecProb real NULL,
			MSGFDB_PValue real NULL,
			MSGFDB_FDR real NULL,
			MSGFDB_PepFDR real NULL

	End

	If @MsaPeptideHit = 1
	Begin
		-- Add the MSAlign specific columns to the temporary tables
		
		ALTER TABLE #TmpPeptidesAndSICStats_Results Add
			MSAlign_PValue real NULL,
			MSAlign_FDR real NULL

		ALTER TABLE #TmpPeptidesAndSICStats Add
			MSAlign_PValue real NULL,
			MSAlign_FDR real NULL
	End
	
/*
	-- No longer used: Add a clustered index on Seq_ID
	CREATE CLUSTERED INDEX IX_Tmp_PeptidesAndSICStats ON #TmpPeptidesAndSICStats(Seq_ID)

	-- No longer used: Add the primary key (spans 5 columns)
	ALTER TABLE #TmpPeptidesAndSICStats
	ADD CONSTRAINT PK_Tmp_PeptidesAndSICStats PRIMARY KEY  NONCLUSTERED (
		Job, Seq_ID, Scan_Number, Charge_State, Reference)
*/

	-- Add an index on Scan_Number and SIC_Job
	CREATE INDEX #IX_Tmp_PeptidesAndSICStats_ScanNumberSICJob ON #TmpPeptidesAndSICStats (Scan_Number, SIC_Job)

	-- Add an index on Seq_ID
	CREATE INDEX #IX_Tmp_PeptidesAndSICStats_Seq_ID ON #TmpPeptidesAndSICStats (Seq_ID)

	--------------------------------------------------------------
	-- Construct the commonly used strings
	--  First loop; construct text for Peptide_Hit jobs (@Iteration = 1)
	--  Second loop; construct text for XT_Peptide_Hit jobs (@Iteration = 2)
	--  Third loop; construct text for IN_Peptide_Hit jobs (@Iteration = 3)
	--  Fourth loop; construct text for MSG_Peptide_Hit jobs (@Iteration = 4)
	--  Fifth loop; construct text for MSA_Peptide_Hit jobs (@Iteration = 5)
	--------------------------------------------------------------
	Declare @Params nvarchar(1024)

	Declare @InsertSqlPeptideHit nvarchar(2048) = ''
	Declare @InsertSqlXTPeptideHit nvarchar(2048) = ''
	Declare @InsertSqlInsPeptideHit nvarchar(2048) = ''
	Declare @InsertSqlMsgPeptideHit nvarchar(2048) = ''
	Declare @InsertSqlMsaPeptideHit nvarchar(2048) = ''
	
	Declare @ColumnNameSqlPeptideHit nvarchar(2048) = ''
	Declare @ColumnNameSqlXTPeptideHit nvarchar(2048) = ''
	Declare @ColumnNameSqlInsPeptideHit nvarchar(2048) = ''
	Declare @ColumnNameSqlMsgPeptideHit nvarchar(2048) = ''
	Declare @ColumnNameSqlMsaPeptideHit nvarchar(2048) = ''
	
	Declare @Iteration int
	
	Set @Iteration = 1
	While @Iteration <= 5
	Begin -- <a0>
		--------------------------------------------------------------
		-- Construct the @InsertSql text
		--------------------------------------------------------------
		Set @S = ''
		Set @S = @S + ' INSERT INTO #TmpPeptidesAndSICStats ('
		Set @S = @S +   ' SIC_Job, Job, Dataset_ID, Dataset, Reference, Seq_ID, Peptide, Monoisotopic_Mass,'
		Set @S = @S +   ' DiscriminantScoreNorm, Peptide_Prophet_Probability, MSGF_SpecProb, '

		If @Iteration = 1
			Set @S = @S +   ' XCorr, '			
		If @Iteration = 2
			Set @S = @S +   ' XCorr, Hyperscore, Log_EValue, '
		If @Iteration = 3
			Set @S = @S +   ' XCorr, MQScore, TotalPRMScore, FScore, '
		If @Iteration = 4
			Set @S = @S +   ' XCorr, MSGFDB_DeNovoScore, MSGFDB_MSGFScore, MSGFDB_SpecProb, MSGFDB_PValue, MSGFDB_FDR, MSGFDB_PepFDR, '
		If @Iteration = 5
			Set @S = @S +   ' XCorr, MSAlign_PValue, MSAlign_FDR, '
			
		Set @S = @S + ' DeltaCn2, Charge_State, Scan_Number, Cleavage_State, RankHit, DelM_PPM)'
		
		Set @S = @S + ' SELECT DISTINCT DS.SIC_Job, TAD.Job, DS.Dataset_ID, TAD.Dataset, Pro.Reference,'
		Set @S = @S +   ' Pep.Seq_ID, Pep.Peptide, S.Monoisotopic_Mass, SD.DiscriminantScoreNorm, '
		Set @S = @S +   ' IsNull(SD.Peptide_Prophet_Probability, 0) AS Peptide_Prophet_Probability,'
		
		If @Iteration = 5
			Set @S = @S +   ' IsNull(SD.MSGF_SpecProb, IsNull(M.PValue, 1)) AS MSGF_SpecProb,'
		Else
			Set @S = @S +   ' IsNull(SD.MSGF_SpecProb, 1) AS MSGF_SpecProb,'
		
		If @Iteration = 1
			Set @S = @S +   ' SS.XCorr, SS.DeltaCn2,'
		If @Iteration = 2
			Set @S = @S +   ' X.Normalized_Score, X.Hyperscore, X.Log_EValue, X.DeltaCn2,'
		If @Iteration = 3
			Set @S = @S +   ' I.Normalized_Score, I.MQScore, I.TotalPRMScore, I.FScore, I.DeltaScore,'
		If @Iteration = 4
			Set @S = @S +   ' M.Normalized_Score, M.DeNovoScore, M.MSGFScore, M.SpecProb, M.PValue, M.FDR, M.PepFDR, 1 AS DelCN2,'
		If @Iteration = 5
			Set @S = @S +   ' M.Normalized_Score, M.PValue, M.FDR, 1 AS DelCN2,'
			
		Set @S = @S +   ' Pep.Charge_State, Pep.Scan_Number, PPM.Cleavage_State, Pep.RankHit, Pep.DelM_PPM'
		Set @S = @S + ' FROM T_Analysis_Description TAD INNER JOIN '
		Set @S = @S +     ' T_Datasets DS ON TAD.Dataset_ID = DS.Dataset_ID INNER JOIN '
		Set @S = @S +     ' T_Peptides Pep ON TAD.Job = Pep.Job INNER JOIN '
		
		If @Iteration = 1
			Set @S = @S +     ' T_Score_Sequest SS ON Pep.Peptide_ID = SS.Peptide_ID INNER JOIN '
		If @Iteration = 2
			Set @S = @S +     ' T_Score_XTandem X ON Pep.Peptide_ID = X.Peptide_ID INNER JOIN '
		If @Iteration = 3
			Set @S = @S +     ' T_Score_Inspect I ON Pep.Peptide_ID = I.Peptide_ID INNER JOIN '
		If @Iteration = 4
			Set @S = @S +     ' T_Score_MSGFDB M ON Pep.Peptide_ID = M.Peptide_ID INNER JOIN '
		If @Iteration = 5
			Set @S = @S +     ' T_Score_MSAlign M ON Pep.Peptide_ID = M.Peptide_ID INNER JOIN '
				
		Set @S = @S +     ' T_Peptide_to_Protein_Map PPM ON Pep.Peptide_ID = PPM.Peptide_ID INNER JOIN '
		Set @S = @S +     ' T_Proteins Pro ON PPM.Ref_ID = Pro.Ref_ID INNER JOIN '
		Set @S = @S +     ' T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID INNER JOIN '
		Set @S = @S +   ' T_Sequence S on Pep.Seq_ID = S.Seq_ID '
	
		If Len(@JobPeptideFilterTableName) > 0
			Set @S = @S + ' INNER JOIN [' + @JobPeptideFilterTableName + '] JPF ON Pep.Job = JPF.Job AND Pep.Peptide = JPF.Peptide '

		Set @S = @S + ' WHERE PPM.Cleavage_State >= @CleavageStateMinimum AND'
		Set @S = @S +  ' TAD.job = @Job AND ('
		
		If @CleavageStateMinimum < 2
			Set @S = @S +    '(PPM.Cleavage_State = 2 AND '
			
		If @Iteration = 1
		Begin
			Set @S = @S +    '(Pep.Charge_State = 1 AND  SS.DeltaCn2 >= @MinDeltaCn AND SS.XCorr >= @MinXCorrFullyTrypticCharge1 OR'
			Set @S = @S +    ' Pep.Charge_State = 2 AND  SS.DeltaCn2 >= @MinDeltaCn AND SS.XCorr >= @MinXCorrFullyTrypticCharge2 OR'
			Set @S = @S +    ' Pep.Charge_State >= 3 AND SS.DeltaCn2 >= @MinDeltaCn AND SS.XCorr >= @MinXCorrFullyTrypticCharge3)'
		End

		If @Iteration = 2
		Begin
			Set @S = @S +    '(Pep.Charge_State = 1 AND  X.DeltaCn2 >= @MinDeltaCn AND X.Normalized_Score >= @MinXCorrFullyTrypticCharge1 OR'
			Set @S = @S +    ' Pep.Charge_State = 2 AND  X.DeltaCn2 >= @MinDeltaCn AND X.Normalized_Score >= @MinXCorrFullyTrypticCharge2 OR'
			Set @S = @S +    ' Pep.Charge_State >= 3 AND X.DeltaCn2 >= @MinDeltaCn AND X.Normalized_Score >= @MinXCorrFullyTrypticCharge3)'
		End

		If @Iteration = 3
		Begin
			Set @S = @S +    '(Pep.Charge_State = 1 AND  I.DeltaScore >= @MinDeltaCn AND I.Normalized_Score >= @MinXCorrFullyTrypticCharge1 OR'
			Set @S = @S +    ' Pep.Charge_State = 2 AND  I.DeltaScore >= @MinDeltaCn AND I.Normalized_Score >= @MinXCorrFullyTrypticCharge2 OR'
			Set @S = @S +    ' Pep.Charge_State >= 3 AND I.DeltaScore >= @MinDeltaCn AND I.Normalized_Score >= @MinXCorrFullyTrypticCharge3)'
		End

		If @Iteration IN (4, 5)
		Begin
			Set @S = @S +    '(Pep.Charge_State = 1 AND  M.Normalized_Score >= @MinXCorrFullyTrypticCharge1 OR'
			Set @S = @S +    ' Pep.Charge_State = 2 AND  M.Normalized_Score >= @MinXCorrFullyTrypticCharge2 OR'
			Set @S = @S +    ' Pep.Charge_State >= 3 AND M.Normalized_Score >= @MinXCorrFullyTrypticCharge3)'
		End

		If @CleavageStateMinimum < 2
		Begin -- <b0>
			Set @S = @S +    ') OR (PPM.Cleavage_State < 2 AND '

			If @Iteration = 1
			Begin
				Set @S = @S +    '(Pep.Charge_State = 1 AND SS.DeltaCn2 >= @MinDeltaCn AND SS.XCorr >= @MinXCorrPartiallyTrypticCharge1 OR'
				Set @S = @S +    ' Pep.Charge_State = 2 AND SS.DeltaCn2 >= @MinDeltaCn AND SS.XCorr >= @MinXCorrPartiallyTrypticCharge2 OR'
				Set @S = @S +    ' Pep.Charge_State >= 3 AND SS.DeltaCn2 >= @MinDeltaCn AND SS.XCorr >= @MinXCorrPartiallyTrypticCharge3)'
			End

			If @Iteration = 2
			Begin
				Set @S = @S +    '(Pep.Charge_State = 1 AND X.DeltaCn2 >= @MinDeltaCn AND X.Normalized_Score >= @MinXCorrPartiallyTrypticCharge1 OR'
				Set @S = @S +    ' Pep.Charge_State = 2 AND X.DeltaCn2 >= @MinDeltaCn AND X.Normalized_Score >= @MinXCorrPartiallyTrypticCharge2 OR'
				Set @S = @S +    ' Pep.Charge_State >= 3 AND X.DeltaCn2 >= @MinDeltaCn AND X.Normalized_Score >= @MinXCorrPartiallyTrypticCharge3)'
			End

			If @Iteration = 3
			Begin
				Set @S = @S +    '(Pep.Charge_State = 1 AND I.DeltaScore >= @MinDeltaCn AND I.Normalized_Score >= @MinXCorrPartiallyTrypticCharge1 OR'
				Set @S = @S +    ' Pep.Charge_State = 2 AND I.DeltaScore >= @MinDeltaCn AND I.Normalized_Score >= @MinXCorrPartiallyTrypticCharge2 OR'
				Set @S = @S +    ' Pep.Charge_State >= 3 AND I.DeltaScore >= @MinDeltaCn AND I.Normalized_Score >= @MinXCorrPartiallyTrypticCharge3)'
			End
			
			If @Iteration IN (4, 5)
			Begin
				Set @S = @S +    '(Pep.Charge_State = 1 AND  M.Normalized_Score >= @MinXCorrPartiallyTrypticCharge1 OR'
				Set @S = @S +    ' Pep.Charge_State = 2 AND  M.Normalized_Score >= @MinXCorrPartiallyTrypticCharge2 OR'
				Set @S = @S +    ' Pep.Charge_State >= 3 AND M.Normalized_Score >= @MinXCorrPartiallyTrypticCharge3)'
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
		If @Iteration = 4
			Set @InsertSqlMsgPeptideHit = @S
		If @Iteration = 5
			Set @InsertSqlMsaPeptideHit = @S
			
		--------------------------------------------------------------
		-- Construct the @ColumnNameSql text
		--------------------------------------------------------------

		Set @S = ''
		Set @S = @S +   ' SIC_Job, Job, Dataset, Reference,' 
		Set @S = @S +   ' Cleavage_State, RankHit, DelM_PPM, Seq_ID, Peptide,'
		Set @S = @S +   ' Monoisotopic_Mass, '
		
		If @Iteration = 1
			Set @S = @S +   ' XCorr,'
		If @Iteration = 2
			Set @S = @S +   ' XCorr, Hyperscore, Log_Evalue,'
		If @Iteration = 3
			Set @S = @S +   ' XCorr, MQScore, TotalPRMScore, FScore,'
		If @Iteration = 4
			Set @S = @S +   ' XCorr, MSGFDB_DeNovoScore, MSGFDB_MSGFScore, MSGFDB_SpecProb, MSGFDB_PValue, MSGFDB_FDR, MSGFDB_PepFDR,'
		If @Iteration = 5
			Set @S = @S +   ' XCorr, MSAlign_PValue, MSAlign_FDR,'

		Set @S = @S +   ' DeltaCn2, Charge_State,'
		Set @S = @S +   ' Discriminant, Peptide_Prophet_Prob, MSGF_SpecProb,'
		Set @S = @S +   ' Optimal_Scan_Number, Elution_Time, '
		Set @S = @S +   ' Intensity, SN, FWHM, Area,'

		Set @S = @S +   ' Parent_Ion_Intensity,'
		Set @S = @S +   ' Parent_Ion_MZ,'
		
		Set @S = @S +   ' MSMS_Scan_Number'

		If @Iteration = 1
			Set @ColumnNameSqlPeptideHit = @S
		If @Iteration = 2
			Set @ColumnNameSqlXTPeptideHit = @S
		If @Iteration = 3
			Set @ColumnNameSqlInsPeptideHit = @S
		If @Iteration = 4
			Set @ColumnNameSqlMsgPeptideHit = @S
		If @Iteration = 5
			Set @ColumnNameSqlMsaPeptideHit = @S
			
		Set @Iteration = @Iteration + 1
	End -- </a0>
	
	-- Params string for sp_ExecuteSql
	Set @Params = '@Job int, @CleavageStateMinimum tinyint, @MinDeltaCn real, @MinXCorrFullyTrypticCharge1 real, @MinXCorrFullyTrypticCharge2 real, @MinXCorrFullyTrypticCharge3 real, @MinXCorrPartiallyTrypticCharge1 real, @MinXCorrPartiallyTrypticCharge2 real, @MinXCorrPartiallyTrypticCharge3 real'

	--------------------------------------------------------------
	-- Obtain the data for each job in #TmpJobList and place in #TmpPeptidesAndSICStats_Results
	--------------------------------------------------------------
	
	Declare @JobIsPeptideHit tinyint
	Declare @JobIsXTPeptideHit tinyint
	Declare @JobIsInsPeptideHit tinyint
	Declare @JobIsMsgPeptideHit tinyint
	Declare @JobIsMsaPeptideHit tinyint

	Declare @Continue tinyint
	
	Declare @JobsProcessed int
	Set @JobsProcessed = 0
	
	Set @Continue = 1
	While @Continue = 1
	Begin -- <a1>
		SELECT TOP 1 @Job = Job, @ResultType = ResultType
		FROM #TmpJobList
		WHERE Job > @Job
		ORDER BY Job
			--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		If @myRowCount <> 1 Or @myError <> 0
			Set @Continue = 0
		Else
		Begin -- <b1>
			-- Job has not yet been processed

			Set @JobIsPeptideHit = 0
			Set @JobIsXTPeptideHit = 0
			Set @JobIsInsPeptideHit = 0
			Set @JobIsMsgPeptideHit = 0
			Set @JobIsMsaPeptideHit = 0
			
			-- Examine @ResultType to determine which Sql to use
			If @ResultType = 'Peptide_Hit'
				Set @JobIsPeptideHit = 1

			If @ResultType = 'XT_Peptide_Hit'
				Set @JobIsXTPeptideHit = 1

			If @ResultType = 'IN_Peptide_Hit'
				Set @JobIsInsPeptideHit = 1

			If @ResultType = 'MSG_Peptide_Hit'
				Set @JobIsMsgPeptideHit = 1
			
			If @ResultType = 'MSA_Peptide_Hit'
				Set @JobIsMsaPeptideHit = 1
				
			TRUNCATE TABLE #TmpPeptidesAndSICStats

			-- Populate the interim processing table with the data for @Job
			If @JobIsPeptideHit = 1
			Begin
				if @PreviewSql <> 0
					Print @InsertSqlPeptideHit
				else
					exec sp_ExecuteSql @InsertSqlPeptideHit, @Params, @Job, @CleavageStateMinimum, @MinDeltaCn, @MinXCorrFullyTrypticCharge1, @MinXCorrFullyTrypticCharge2, @MinXCorrFullyTrypticCharge3, @MinXCorrPartiallyTrypticCharge1, @MinXCorrPartiallyTrypticCharge2, @MinXCorrPartiallyTrypticCharge3
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
			End
			
			If @JobIsXTPeptideHit = 1
			Begin
				if @PreviewSql <> 0
					Print @InsertSqlXTPeptideHit
				else
					exec sp_ExecuteSql @InsertSqlXTPeptideHit, @Params, @Job, @CleavageStateMinimum, @MinDeltaCn, @MinXCorrFullyTrypticCharge1, @MinXCorrFullyTrypticCharge2, @MinXCorrFullyTrypticCharge3, @MinXCorrPartiallyTrypticCharge1, @MinXCorrPartiallyTrypticCharge2, @MinXCorrPartiallyTrypticCharge3
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
			End

			If @JobIsInsPeptideHit = 1
			Begin
				if @PreviewSql <> 0
					Print @InsertSqlInsPeptideHit
				else
					exec sp_ExecuteSql @InsertSqlInsPeptideHit, @Params, @Job, @CleavageStateMinimum, @MinDeltaCn, @MinXCorrFullyTrypticCharge1, @MinXCorrFullyTrypticCharge2, @MinXCorrFullyTrypticCharge3, @MinXCorrPartiallyTrypticCharge1, @MinXCorrPartiallyTrypticCharge2, @MinXCorrPartiallyTrypticCharge3
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
			End
			
			If @JobIsMsgPeptideHit = 1
			Begin
				if @PreviewSql <> 0
					Print @InsertSqlMsgPeptideHit
				else
					exec sp_ExecuteSql @InsertSqlMsgPeptideHit, @Params, @Job, @CleavageStateMinimum, @MinDeltaCn, @MinXCorrFullyTrypticCharge1, @MinXCorrFullyTrypticCharge2, @MinXCorrFullyTrypticCharge3, @MinXCorrPartiallyTrypticCharge1, @MinXCorrPartiallyTrypticCharge2, @MinXCorrPartiallyTrypticCharge3
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
			End

			If @JobIsMsaPeptideHit = 1
			Begin
				if @PreviewSql <> 0
					Print @InsertSqlMsaPeptideHit
				else
					exec sp_ExecuteSql @InsertSqlMsaPeptideHit, @Params, @Job, @CleavageStateMinimum, @MinDeltaCn, @MinXCorrFullyTrypticCharge1, @MinXCorrFullyTrypticCharge2, @MinXCorrFullyTrypticCharge3, @MinXCorrPartiallyTrypticCharge1, @MinXCorrPartiallyTrypticCharge2, @MinXCorrPartiallyTrypticCharge3
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
			End


			If @PreviewSql <> 0
			Begin
				Print 'Params for previous Insert Into query: ' + @Params
				SELECT @Job as Job, 
						@CleavageStateMinimum AS CleavageStateMinimum, 
						@MinDeltaCn As MinDeltaCN, 
						@MinXCorrFullyTrypticCharge1 as MinXCorrCharge1, 
						@MinXCorrFullyTrypticCharge2 as MinXCorrCharge2, 
						@MinXCorrFullyTrypticCharge3 as MinXCorrCharge3, 
						@MinXCorrPartiallyTrypticCharge1 as MinXCorrPartiallyTrypticCharge1, 
						@MinXCorrPartiallyTrypticCharge2 as MinXCorrPartiallyTrypticCharge2, 
						@MinXCorrPartiallyTrypticCharge3 as MinXCorrPartiallyTrypticCharge3

			End
			Else
			Begin -- <c1>
				
				-- Update the interim processing table to include the DS_SIC data	
				UPDATE #TmpPeptidesAndSICStats
				SET Optimal_Peak_Apex_Scan_Number = DS_SIC.Optimal_Peak_Apex_Scan_Number, 
					Peak_Intensity = DS_SIC.Peak_Intensity, 
					Peak_SN_Ratio = DS_SIC.Peak_SN_Ratio, 
					FWHM_In_Scans = DS_SIC.FWHM_In_Scans,
					Peak_Area = DS_SIC.Peak_Area, 
					Parent_Ion_Intensity = DS_SIC.Parent_Ion_Intensity,
					Parent_Ion_MZ = DS_SIC.MZ
				FROM #TmpPeptidesAndSICStats S INNER JOIN
					 T_Dataset_Stats_SIC DS_SIC ON 
					 DS_SIC.Frag_Scan_Number = S.Scan_Number AND 
					 DS_SIC.Job = S.SIC_Job
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				If @GroupByPeptide = 0
				Begin
					--------------------------------------------------------------
					-- Do not group by peptide; append all of the data to #TmpPeptidesAndSICStats_Results
					--------------------------------------------------------------
					Set @UseValueMinimum = 0
				End
				Else
				Begin -- <d1>
					--------------------------------------------------------------
					-- Group By the metric indicated by @MaxValueSelectionMode
					-- First, need to flag the row with the highest given value for each Seq_ID
					--------------------------------------------------------------
					
					Set @UseValueMinimum = 1
						
					-- Define the Selection Field based on @MaxValueSelectionMode
					-- Default to use Peak_Area
					Set @SelectionField = 'Peak_Area'
					Set @SelectionAggregator = 'MAX'
					
					If @MaxValueSelectionMode = 0
						Set @SelectionField = 'Peak_Area'

					If @MaxValueSelectionMode = 1
						Set @SelectionField = 'Peak_SN_Ratio'

					If @MaxValueSelectionMode = 2
						Set @SelectionField = 'StatMoments_Area'

					If @JobIsPeptideHit = 1
					Begin
						If @MaxValueSelectionMode >= 3
							Set @SelectionField = 'XCorr'
					End

					If @JobIsXTPeptideHit = 1
					Begin
						If @MaxValueSelectionMode = 3
							Set @SelectionField = 'Hyperscore'

						If @MaxValueSelectionMode = 4
						Begin
							Set @SelectionField = 'Log_Evalue'
							Set @SelectionAggregator = 'MIN'
						End
					End
					
					If @JobIsInsPeptideHit = 1
					Begin
						If @MaxValueSelectionMode = 3
							Set @SelectionField = 'MQScore'

						If @MaxValueSelectionMode = 4
							Set @SelectionField = 'FScore'
					End
					
					If @JobIsMsgPeptideHit = 1
					Begin
						If @MaxValueSelectionMode = 3
						Begin
							Set @SelectionField = 'MSGFDB_MSGFScore'
							Set @SelectionAggregator = 'MIN'
						End
					End
					
					If @JobIsMsaPeptideHit = 1
					Begin
						If @MaxValueSelectionMode = 3
						Begin
							Set @SelectionField = 'MSAlign_PValue'
							Set @SelectionAggregator = 'MIN'
						End
					End
									
					Set @S = ''
					Set @S = @S + ' UPDATE #TmpPeptidesAndSICStats'
					Set @S = @S + ' SET UseValue = 1'
					Set @S = @S + ' FROM #TmpPeptidesAndSICStats S INNER JOIN'
					Set @S = @S +    ' ( SELECT MIN(S.Unique_Row_ID) AS Unique_Row_ID_Min'
					Set @S = @S +   ' FROM #TmpPeptidesAndSICStats S INNER JOIN'
					Set @S = @S +       ' ( SELECT SIC_Job, Seq_ID, ' + @SelectionAggregator + '(' + @SelectionField + ') AS Value_Best'
					If @GroupByChargeState <> 0
						Set @S = @S +			  ', Charge_State'
					Set @S = @S +         ' FROM #TmpPeptidesAndSICStats'
					Set @S = @S +         ' GROUP BY SIC_Job, Seq_ID'
					If @GroupByChargeState <> 0
						Set @S = @S +				', Charge_State'
					Set @S = @S +       ' ) LookupQ ON'
					Set @S = @S +       ' S.SIC_Job = LookupQ.SIC_Job AND'
					Set @S = @S +       ' S.Seq_ID = LookupQ.Seq_ID AND'
					If @GroupByChargeState <> 0
						Set @S = @S +   ' S.Charge_State = LookupQ.Charge_State AND'
					Set @S = @S +       ' S.' + @SelectionField + ' = LookupQ.Value_Best'
					Set @S = @S +      ' GROUP BY S.Seq_ID'
					If @GroupByChargeState <> 0
						Set @S = @S +				', S.Charge_State'
					Set @S = @S +    ' ) UniqueRowQ ON'
					Set @S = @S +    ' S.Unique_Row_ID = UniqueRowQ.Unique_Row_ID_Min'
					
					exec sp_ExecuteSql @S
					--
					SELECT @myRowCount = @@rowcount, @myError = @@error							
				
				End -- </d1>
			End -- </c1>

			--------------------------------------------------------------
			-- Append the desired data to #TmpPeptidesAndSICStats_Results
			-- We have to use dynamic SQL here because the table may not contain
			--  columns Hyperscore or Log_Evalue
			--------------------------------------------------------------
			--
			Set @S = ''
			Set @S = @S + ' INSERT INTO #TmpPeptidesAndSICStats_Results ('

			If @JobIsPeptideHit = 1
				Set @S = @S + @ColumnNameSqlPeptideHit

			If @JobIsXTPeptideHit = 1
				Set @S = @S + @ColumnNameSqlXTPeptideHit

			If @JobIsInsPeptideHit = 1
				Set @S = @S + @ColumnNameSqlInsPeptideHit
			
			If @JobIsMsgPeptideHit = 1
				Set @S = @S + @ColumnNameSqlMsgPeptideHit
			
			If @JobIsMsaPeptideHit = 1
				Set @S = @S + @ColumnNameSqlMsaPeptideHit
			
			Set @S = @S + ' )'
			Set @S = @S + ' SELECT S.SIC_Job, S.Job, S.Dataset, S.Reference,'
			Set @S = @S +   ' S.Cleavage_State, S.RankHit, S.DelM_PPM, S.Seq_ID, S.Peptide,'
			Set @S = @S +   ' S.Monoisotopic_Mass, '
			
			If @JobIsPeptideHit = 1
				Set @S = @S +   ' S.XCorr,'
			If @JobIsXTPeptideHit = 1
				Set @S = @S +   ' S.XCorr, S.Hyperscore,S.Log_Evalue,'
			If @JobIsInsPeptideHit = 1
				Set @S = @S +   ' S.XCorr, S.MQScore, S.TotalPRMScore, S.FScore,'
			If @JobIsMsgPeptideHit = 1
				Set @S = @S +   ' S.XCorr, S.MSGFDB_DeNovoScore, S.MSGFDB_MSGFScore, S.MSGFDB_SpecProb, S.MSGFDB_PValue, S.MSGFDB_FDR, S.MSGFDB_PepFDR, '
			If @JobIsMsaPeptideHit = 1
				Set @S = @S +   ' S.XCorr, S.MSAlign_PValue, S.MSAlign_FDR, '
				
			Set @S = @S +   ' S.DeltaCn2, S.Charge_State,'
			Set @S = @S +   ' S.DiscriminantScoreNorm, S.Peptide_Prophet_Probability, S.MSGF_SpecProb,'
			Set @S = @S +   ' S.Optimal_Peak_Apex_Scan_Number, DS_Scans.Scan_Time,'
			Set @S = @S +   ' S.Peak_Intensity, S.Peak_SN_Ratio, S.FWHM_In_Scans, S.Peak_Area,'
			Set @S = @S +   ' Parent_Ion_Intensity,'
			Set @S = @S +   ' Parent_Ion_MZ,'
			Set @S = @S +   ' S.Scan_Number'
			Set @S = @S + ' FROM #TmpPeptidesAndSICStats S INNER JOIN'
			Set @S = @S +   ' T_Dataset_Stats_Scans DS_Scans ON'
			Set @S = @S +   ' S.SIC_Job = DS_Scans.Job AND'
			Set @S = @S +   ' S.Optimal_Peak_Apex_Scan_Number = DS_Scans.Scan_Number'
			Set @S = @S + ' WHERE S.UseValue >= ' + Convert(varchar(6), @UseValueMinimum)
			Set @S = @S + ' ORDER BY S.Dataset, S.Job, S.XCorr DESC, S.Seq_ID'

			If @PreviewSql <> 0
				Print @S
			Else
				exec sp_ExecuteSql @S
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error	
			
			If @GroupByPeptide <> 0 And @ReportHighestScoreStatsInJob <> 0
			Begin -- <c2>
				-- Update the data in #TmpPeptidesAndSICStats_Results for this job to reflect the maximum scores for each peptide

				If @JobIsPeptideHit = 1
				Begin
					Set @SelectionField = 'XCorr'
					Set @SelectionAggregator = 'MAX'
				End
				
				If @JobIsXTPeptideHit = 1
				Begin
					Set @SelectionField = 'Hyperscore'
					Set @SelectionAggregator = 'MAX'
				End
			
				If @JobIsInsPeptideHit = 1
				Begin
					Set @SelectionField = 'MQScore'
					Set @SelectionAggregator = 'MAX'
				End
				
				If @JobIsMsgPeptideHit = 1
				Begin
					Set @SelectionField = 'MSGFDB_MSGFScore'
					Set @SelectionAggregator = 'MIN'
				End

				If @JobIsMsaPeptideHit = 1
				Begin
					Set @SelectionField = 'MSAlign_PValue'
					Set @SelectionAggregator = 'MIN'
				End
				
				If @MaxValueSelectionMode < 3
				Begin -- <d3>
					Set @S = ''
					Set @S = @S + ' UPDATE #TmpPeptidesAndSICStats_Results'
					Set @S = @S + ' SET XCorr = MaxValuesQ.XCorr,'
					Set @S = @S +     ' DeltaCn2 = MaxValuesQ.DeltaCn2,'
					Set @S = @S + ' Charge_State = MaxValuesQ.Charge_State,'
					Set @S = @S +     ' MSMS_Scan_Number = MaxValuesQ.Scan_Number'
					
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
					
					If @JobIsMsgPeptideHit = 1
					Begin
						Set @S = @S + ' , MSGFDB_MSGFScore = MaxValuesQ.MSGFDB_MSGFScore'
						Set @S = @S + ' , MSGFDB_FDR = MaxValuesQ.MSGFDB_FDR'
						Set @S = @S + ' , MSGFDB_PepFDR = MaxValuesQ.MSGFDB_PepFDR'
					End
					
					If @JobIsMsaPeptideHit = 1
					Begin
						Set @S = @S + ' , MSAlign_PValue = MaxValuesQ.MSAlign_PValue'
						Set @S = @S + ' , MSAlign_FDR = MaxValuesQ.MSAlign_FDR'
					End
					
					Set @S = @S + ' FROM #TmpPeptidesAndSICStats_Results Target INNER JOIN'
					Set @S = @S + ' ( SELECT S.SIC_Job, S.Seq_ID, S.XCorr, S.DeltaCn2, S.Charge_State, S.Scan_Number'
					
					If @JobIsXTPeptideHit = 1
						Set @S = @S +    ' , S.Hyperscore, S.Log_EValue'

					If @JobIsInsPeptideHit = 1
						Set @S = @S +    ' , S.MQScore, S.TotalPRMScore, S.FScore'
						
					If @JobIsMsgPeptideHit = 1
						Set @S = @S +    ' , S.MSGFDB_MSGFScore, S.MSGFDB_FDR, S.MSGFDB_PepFDR'

					If @JobIsMsaPeptideHit = 1
						Set @S = @S +    ' , S.MSAlign_PValue, S.MSAlign_FDR'
												
					Set @S = @S +   ' FROM #TmpPeptidesAndSICStats S INNER JOIN'
					Set @S = @S +      ' ( SELECT MIN(S.Unique_Row_ID) AS Unique_Row_ID_Min'
					Set @S = @S +        ' FROM #TmpPeptidesAndSICStats S INNER JOIN'
					Set @S = @S +         ' ( SELECT SIC_Job, Seq_ID, ' + @SelectionAggregator + '(' + @SelectionField + ') AS Value_Best'
					If @GroupByChargeState <> 0
						Set @S = @S +			  ', Charge_State'
					Set @S = @S +           ' FROM #TmpPeptidesAndSICStats'
					Set @S = @S +     ' GROUP BY SIC_Job, Seq_ID'
					If @GroupByChargeState <> 0
						Set @S = @S +				', Charge_State'
					Set @S = @S +         ' ) LookupQ ON'
					Set @S = @S +         ' S.SIC_Job = LookupQ.SIC_Job AND'
					Set @S = @S +         ' S.Seq_ID = LookupQ.Seq_ID AND'
					If @GroupByChargeState <> 0
						Set @S = @S +     ' S.Charge_State = LookupQ.Charge_State AND'
					Set @S = @S +         ' S.' + @SelectionField + ' = LookupQ.Value_Best'
					Set @S = @S +         ' GROUP BY S.Seq_ID'
					If @GroupByChargeState <> 0
						Set @S = @S +				', S.Charge_State'
					Set @S = @S +      ' ) UniqueRowQ ON'
					Set @S = @S +      ' S.Unique_Row_ID = UniqueRowQ.Unique_Row_ID_Min'
					Set @S = @S +   ' ) MaxValuesQ ON Target.Seq_ID = MaxValuesQ.Seq_ID AND Target.SIC_Job = MaxValuesQ.SIC_Job'
					If @GroupByChargeState <> 0
						Set @S = @S +   ' AND Target.Charge_State = MaxValuesQ.Charge_State'
														
					If @PreviewSql <> 0
						Print @S
					Else
						exec sp_ExecuteSql @S
					--
					SELECT @myRowCount = @@rowcount, @myError = @@error
				End -- <d2>

				Set @S = ''
				Set @S = @S + ' UPDATE #TmpPeptidesAndSICStats_Results'
				Set @S = @S + ' SET Discriminant = MaxValuesQ.DiscriminantScoreNorm,'
				Set @S = @S +     ' Peptide_Prophet_Prob = MaxValuesQ.Peptide_Prophet_Probability,'
				Set @S = @S +     ' MSGF_SpecProb = MaxValuesQ.MSGF_SpecProb'
				Set @S = @S + ' FROM #TmpPeptidesAndSICStats_Results Target INNER JOIN'
				Set @S = @S + ' ( SELECT SIC_Job, Seq_ID,'
				Set @S = @S +          ' MAX(DiscriminantScoreNorm) AS DiscriminantScoreNorm,'
				Set @S = @S +          ' MAX(Peptide_Prophet_Probability) AS Peptide_Prophet_Probability,'
				Set @S = @S +          ' MIN(MSGF_SpecProb) AS MSGF_SpecProb'
				If @GroupByChargeState <> 0
					Set @S = @S +    ', Charge_State'
				Set @S = @S +  ' FROM #TmpPeptidesAndSICStats'
				Set @S = @S +   ' GROUP BY SIC_Job, Seq_ID'
				If @GroupByChargeState <> 0
					Set @S = @S +         ', Charge_State'
				Set @S = @S + ' ) MaxValuesQ ON Target.Seq_ID = MaxValuesQ.Seq_ID AND Target.SIC_Job = MaxValuesQ.SIC_Job'
				If @GroupByChargeState <> 0
					Set @S = @S + ' AND Target.Charge_State = MaxValuesQ.Charge_State'
									
				If @PreviewSql <> 0
					Print @S
				Else
					exec sp_ExecuteSql @S
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

			End -- </c2>
			
		End -- </b1>
		
		If @PreviewSql <> 0
			Set @Continue = 0
		
		Set @JobsProcessed = @JobsProcessed + 1
		
		If @MaxJobsToProcess > 0 And @JobsProcessed >= @MaxJobsToProcess
			Set @Continue = 0
			
	End -- </a1>

	If Len(@JobScanRequiredTableName) > 0
	Begin -- <a2>
		-- Need to step through the jobs in @JobScanRequiredTableName and make sure data for the specified scans is present
		
		CREATE TABLE #TmpScansToAdd (
			Scan_Number int NOT NULL
		)
		
		-- Clear #TmpJobList
		DELETE FROM #TmpJobList
		
		-- Populate #TmpJobList using @JobScanRequiredTableName
		Set @S = ''
		Set @S = @S + ' INSERT INTO #TmpJobList (Job)'
		Set @S = @S + ' SELECT DISTINCT Job'
		Set @S = @S + ' FROM [' + @JobScanRequiredTableName + ']'
		--

		If @PreviewSql <> 0
			Print @S

		exec sp_ExecuteSql @S
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
		If @myRowCount = 0
			Print 'Warning: no data found in "' + @JobScanRequiredTableName + '"'
		Else
		Begin -- <b2>
			
			-- Populate the ResultType field
			UPDATE #TmpJobList
			SET ResultType= TAD.ResultType
			FROM #TmpJobList INNER JOIN
				T_Analysis_Description TAD ON #TmpJobList.Job = TAD.Job
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error


			-- Delete any jobs from #TmpJobList that are not in T_Analysis_Description (and thus have Null ResultType)
			DELETE FROM #TmpJobList
			WHERE ResultType Is Null
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			If @myRowCount > 0
				Print 'Warning: ' + Convert(varchar(12), @myRowCount) + ' jobs in "' + @JobScanRequiredTableName + '" were not present in T_Analysis_Description; they will be skipped'


			-- Delete any jobs from #TmpJobList that are not Sequest, XTandem, Inspect, or MSGF-DB jobs
			DELETE FROM #TmpJobList
			WHERE NOT ResultType IN ('Peptide_Hit', 'XT_Peptide_Hit', 'IN_Peptide_Hit', 'MSG_Peptide_Hit')
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			If @myRowCount > 0
				Print 'Warning: ' + Convert(varchar(12), @myRowCount) + ' jobs in "' + @JobScanRequiredTableName + '" were not Sequest or XTandem jobs; they will be skipped'


			-- Now loop through the jobs in #TmpJobList

			SELECT @Job = MIN(Job)-1, 
				   @JobCount = COUNT(*)
			FROM #TmpJobList

			Set @JobsProcessed = 0
			
			Set @Continue = 1
			While @Continue = 1
			Begin -- <c3>
			
				SELECT TOP 1 @Job = JL.Job,
							 @Dataset = TAD.Dataset
				FROM #TmpJobList JL INNER JOIN 
					 T_Analysis_Description TAD ON
					  JL.Job = TAD.Job
				WHERE JL.Job > @Job
				ORDER BY JL.Job
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				If @myRowCount <> 1 Or @myError <> 0
					Set @Continue = 0
				Else
				Begin -- <d1>
					-- Job has not yet been processed
					
					-- Determine the corresponding MASIC job for this Sequest/X!Tandem Job

					SELECT DISTINCT @SICJob = DS.SIC_Job
					FROM T_Analysis_Description TAD INNER JOIN
						 T_Datasets DS ON TAD.Dataset_ID = DS.Dataset_ID
					WHERE TAD.Job = @Job
					--
					SELECT @myRowCount = @@rowcount, @myError = @@error

					If @myRowCount = 0 Or @SICJob Is Null
						Print 'Warning: SIC Job not found for job ' + Convert(varchar(12), @Job)
					Else
					Begin -- <e>
						-- Populate a temporary table with the list of Scan numbers that are missing for this job
						
						TRUNCATE TABLE #TmpScansToAdd
						
						Set @S = ''
						Set @S = @S + ' INSERT INTO #TmpScansToAdd (Scan_Number)'
						Set @S = @S + ' SELECT DISTINCT Src.Scan_Number'
						Set @S = @S + ' FROM [' + @JobScanRequiredTableName + '] Src LEFT OUTER JOIN'
						Set @S = @S +      ' #TmpPeptidesAndSICStats_Results Target ON'
						Set @S = @S +        ' Src.Job = Target.Job AND Src.Scan_Number = Target.MSMS_Scan_Number'
						Set @S = @S + ' WHERE Src.Job = ' + Convert(varchar(12), @Job) + ' AND Target.MSMS_Scan_Number Is Null'
						
						If @PreviewSql <> 0
							Print @S
						Else
							exec sp_ExecuteSql @S
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error
						

						If @myRowCount > 0 Or @PreviewSql <> 0
						Begin -- <f>
							
							Set @S = ''
							Set @S = @S + ' INSERT INTO #TmpPeptidesAndSICStats_Results ('
							Set @S = @S +    ' SIC_Job, Job, Dataset,'

							Set @S = @S +    ' Optimal_Scan_Number,'
							Set @S = @S +    ' Elution_Time,'
							Set @S = @S +    ' Intensity,'
							Set @S = @S +    ' SN,'
							Set @S = @S +    ' FWHM,'
							Set @S = @S +    ' Area,'
							Set @S = @S +    ' Parent_Ion_Intensity,'
							Set @S = @S +    ' Parent_Ion_MZ,'
							Set @S = @S +    ' MSMS_Scan_Number'
							Set @S = @S +    ' )'
							
							Set @S = @S + ' SELECT DS_SIC.Job, ' + Convert(varchar(12), @Job) + ', ''' + @Dataset + ''','
							Set @S = @S +    ' DS_SIC.Optimal_Peak_Apex_Scan_Number,'
							Set @S = @S +    ' DS_Scans.Scan_Time,'
							Set @S = @S +    ' DS_SIC.Peak_Intensity, '
							Set @S = @S +    ' DS_SIC.Peak_SN_Ratio, '
							Set @S = @S +    ' DS_SIC.FWHM_In_Scans,'
							Set @S = @S +    ' DS_SIC.Peak_Area, '

							Set @S = @S +    ' DS_SIC.Parent_Ion_Intensity,'
							Set @S = @S +    ' DS_SIC.MZ,'
							Set @S = @S +    ' DS_SIC.Frag_Scan_Number'
								
							Set @S = @S + ' FROM #TmpScansToAdd ScanList INNER JOIN'
							Set @S = @S +   ' T_Dataset_Stats_SIC DS_SIC ON '
							Set @S = @S +     ' DS_SIC.Frag_Scan_Number = ScanList.Scan_Number AND '
							Set @S = @S +     ' DS_SIC.Job = ' + Convert(varchar(12), @SICJob) + ' INNER JOIN'
							Set @S = @S +   ' T_Dataset_Stats_Scans DS_Scans ON'
							Set @S = @S +     ' DS_SIC.Job = DS_Scans.Job AND'
							Set @S = @S +     ' DS_SIC.Frag_Scan_Number = DS_Scans.Scan_Number'


						If @PreviewSql <> 0
							Print @S
						Else
							exec sp_ExecuteSql @S
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error

						End -- </f>
						
						
					End -- </e>		
				End -- </d3>
				
				If @PreviewSql <> 0
					Set @Continue = 0

				Set @JobsProcessed = @JobsProcessed + 1

				If @MaxJobsToProcess > 0 And @JobsProcessed >= @MaxJobsToProcess
					Set @Continue = 0

			End -- </c3>
		End -- </b2>

		If @PreviewSql <> 0
			Set @Continue =0
			
	End -- </a2>

	--------------------------------------------------------------
	-- Query #TmpPeptidesAndSICStats_Results to obtain the data
	--------------------------------------------------------------

	If @PeptideHit = 1
		Set @S = 'SELECT ' + @ColumnNameSqlPeptideHit

	If @XTPeptideHit = 1
		Set @S = 'SELECT ' + @ColumnNameSqlXTPeptideHit

	If @InsPeptideHit = 1
		Set @S = 'SELECT ' + @ColumnNameSqlInsPeptideHit

	If @MsgPeptideHit = 1
		Set @S = 'SELECT ' + @ColumnNameSqlMsgPeptideHit

	If @MsaPeptideHit = 1
		Set @S = 'SELECT ' + @ColumnNameSqlMsaPeptideHit

	Set @S = @S + '	FROM #TmpPeptidesAndSICStats_Results'
	Set @S = @S + '	ORDER BY Dataset, Job, XCorr DESC, Seq_ID'

	If @PreviewSql <> 0
		Print @S
	Else
		exec sp_ExecuteSql @S
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error							

Done:
	If @myError <> 0
		SELECT @Message As ErrorMessage
			
	Return @myError


GO
GRANT EXECUTE ON [dbo].[GetPeptidesAndSICStats] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetPeptidesAndSICStats] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetPeptidesAndSICStats] TO [MTS_DB_Lite] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[GetPeptidesAndSICStats] TO [MTUser] AS [dbo]
GO
