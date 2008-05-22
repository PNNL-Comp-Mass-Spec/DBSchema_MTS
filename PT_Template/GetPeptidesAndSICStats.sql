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
**    
*****************************************************/
(
	@JobList varchar(4000),							-- Comma separated list of Sequest job numbers
	@CleavageStateMinimum tinyint = 2,
	@GroupByPeptide tinyint = 1,					-- If 1, then group by peptide, returning the max value (specified by @MaxValueSelectionMode) for each sequence in each job
	@GroupByChargeState tinyint = 0,				-- If 1, then reports separate values for each charge state; only valid if @GroupByPeptide = 1
	@MaxValueSelectionMode tinyint = 0,				-- 0 means use Peak_Area, 1 means use Peak_SN_Ratio, 2 means use StatMoments_Area, 3 means use XCorr or Hyperscore, 4 means Log_Evalue (only applicable for XTandem)
	@ReportHighestScoreStatsInJob tinyint = 1,		-- Only applicable if @GroupByPeptide = 1 and if @MaxValueSelectionMode is not 3 or 4; when 1, then finds the entry with the max area or SN_Ratio, but updates the Sequest/X!Tandem score stats to reflect the highest scores in the analysis job
	@MinXCorrFullyTrypticCharge1 real = 1.9,		-- Only used for fully tryptic peptides
	@MinXCorrFullyTrypticCharge2 real = 2.2,		-- Only used for fully tryptic peptides
	@MinXCorrFullyTrypticCharge3 real = 3.75,		-- Only used for fully tryptic peptides
	@MinDeltaCn real = 0.1,							-- This is actually DeltaCn2
	@MinXCorrPartiallyTrypticCharge1 real = 4.0,					-- Only used if @CleavageStateMinimum is < 2
	@MinXCorrPartiallyTrypticCharge2 real = 4.3,					-- Only used if @CleavageStateMinimum is < 2
	@MinXCorrPartiallyTrypticCharge3 real = 4.7,					-- Only used if @CleavageStateMinimum is < 2
	@JobPeptideFilterTableName varchar(128) = '',			-- If provided, then will filter the results to only include peptides defined in this table; the table must have fields Job and Peptide and the peptides must be in the format A.BCDEFGH.I
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

	--------------------------------------------------------------
	-- Validate the inputs
	--------------------------------------------------------------
	
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
	
	Set @message = ''


	--------------------------------------------------------------
	-- Parse out each of the jobs in @JobList
	-- Populate #TmpJobList with the job numbers and Result_Type of each job
	--------------------------------------------------------------

	CREATE TABLE #TmpJobList (
		Job int NOT NULL ,
		ResultType varchar(32) NULL
	)
			
	-- Make sure @JobList ends in a comma
	Set @JobList = LTrim(RTrim(@JobList)) + ','
	
	Declare @Job int
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
				WHERE Job = @Job AND ResultType IN ('Peptide_Hit', 'XT_Peptide_Hit')
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				If @myRowCount > 0
					Set @JobCount = @JobCount + 1
			End
		End	

		Set @CommaLoc = CharIndex(',', @JobList)
	End
	
	
	--------------------------------------------------------------
	-- Make sure at least one valid job was specified
	--------------------------------------------------------------
	
	SELECT @Job = MIN(Job)-1, 
		   @JobCount = COUNT(*)
	FROM #TmpJobList

	If @JobCount = 0
	Begin
		Set @Message = 'Could not find any known, valid jobs in @JobList; valid result types are "Peptide_Hit" and "XT_Peptide_Hit", and not "SIC"; in other words, use Sequest and XTandem job numbers, not MASIC'
		Set @myError = 20000
		Goto Done
	End

	--------------------------------------------------------------
	-- Determine which ResultTypes are present
	--------------------------------------------------------------

	Declare @PeptideHit tinyint
	Declare @XTPeptideHit tinyint
	
	If Exists (SELECT Job FROM #TmpJobList WHERE ResultType = 'Peptide_Hit')
		Set @PeptideHit = 1
	Else
		Set @PeptideHit = 0

	If Exists (SELECT Job FROM #TmpJobList WHERE ResultType = 'XT_Peptide_Hit')
		Set @XTPeptideHit = 1
	Else
		Set @XTPeptideHit = 0


	--------------------------------------------------------------
	-- Retrieve the data for each job, using temporary table #TmpPeptidesAndSICStats
	-- as an interim processing table to reduce query complexity and
	-- placing the results in temporary table #TmpPeptidesAndSICStats_Results
	--------------------------------------------------------------

/*
	if exists (select * from dbo.sysobjects where id = object_id(N'#TmpPeptidesAndSICStats_Results') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table #TmpPeptidesAndSICStats_Results

	
	if exists (select * from dbo.sysobjects where id = object_id(N'#TmpPeptidesAndSICStats') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table #TmpPeptidesAndSICStats
*/

	-- Create the temporary results table
	CREATE TABLE #TmpPeptidesAndSICStats_Results (
		SIC_Job int NOT NULL ,
		Job int NOT NULL ,
		Dataset varchar(128) NOT NULL ,
		Reference varchar(255) NOT NULL ,
		Cleavage_State tinyint NULL,
		Seq_ID int NOT NULL ,
		Peptide varchar(850) ,
		Monoisotopic_Mass float NULL,
		XCorr real NULL ,				-- Note: XTandem data will populate this column with the estimated equivalent XCorr given the Hyperscore
				
		DeltaCn2 real NULL ,
		Charge_State smallint NULL,
		Discriminant real NULL ,
		Peptide_Prophet_Prob real NULL ,
		Optimal_Scan_Number real NULL ,
		Elution_Time real NULL,
		Intensity float NULL,
		SN real NULL,
		FWHM int NULL,
		Area float NULL,
		
		Parent_Ion_Intensity real NULL,
		Parent_Ion_MZ real NULL,
		Peak_Baseline_Noise_Level real NULL,
		Peak_Baseline_Noise_StDev real NULL,
		Peak_Baseline_Points_Used smallint NULL,
		
		StatMoments_Area real NULL,
		CenterOfMass_Scan int NULL,
		Peak_StDev real NULL,
		Peak_Skew real NULL,
		Peak_KSStat real NULL,
		StatMoments_DataCount_Used smallint NULL,
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
		XCorr real NULL ,

		DeltaCn2 real NULL ,
		Charge_State smallint NOT NULL ,
		Scan_Number int NOT NULL,
		Cleavage_State tinyint NULL,

		Optimal_Peak_Apex_Scan_Number int NULL,
		Peak_Intensity float NULL,
		Parent_Ion_MZ real NULL,
		Peak_SN_Ratio real NULL,
		FWHM_In_Scans int NULL,
		Peak_Area float NULL,

		Parent_Ion_Intensity real NULL,
		Peak_Baseline_Noise_Level real NULL,
		Peak_Baseline_Noise_StDev real NULL,
		Peak_Baseline_Points_Used smallint NULL,

		StatMoments_Area real NULL,
		CenterOfMass_Scan int NULL,
		Peak_StDev real NULL,
		Peak_Skew real NULL,
		Peak_KSStat real NULL,
		StatMoments_DataCount_Used smallint NULL,

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
	--  First loop; construct text for Peptide_Hit jobs
	--  Second loop; construct text for XT_Peptide_Hit jobs
	--------------------------------------------------------------
	Declare @S nvarchar(max)
	Declare @Params nvarchar(1024)

	Declare @InsertSqlPeptideHit nvarchar(2048)
	Declare @InsertSqlXTPeptideHit nvarchar(2048)
	
	Declare @ColumnNameSqlPeptideHit nvarchar(2048)
	Declare @ColumnNameSqlXTPeptideHit nvarchar(2048)
	
	Declare @Loop int

	Set @Loop = 1
	While @Loop <= 2
	Begin
		--------------------------------------------------------------
		-- Construct the @InsertSql text
		--------------------------------------------------------------
		Set @S = ''
		Set @S = @S + ' INSERT INTO #TmpPeptidesAndSICStats ('
		Set @S = @S +   ' SIC_Job, Job, Dataset_ID, Dataset, Reference, Seq_ID, Peptide, Monoisotopic_Mass,'
		Set @S = @S +   ' DiscriminantScoreNorm, Peptide_Prophet_Probability, XCorr, '
		If @Loop = 2
			Set @S = @S +   ' Hyperscore, Log_EValue, '

		Set @S = @S + ' DeltaCn2, Charge_State, Scan_Number, Cleavage_State)'
		Set @S = @S + ' SELECT DISTINCT DS.SIC_Job, TAD.Job, DS.Dataset_ID, TAD.Dataset, Pro.Reference,'
		Set @S = @S +   ' Pep.Seq_ID, Pep.Peptide, S.Monoisotopic_Mass, SD.DiscriminantScoreNorm, SD.Peptide_Prophet_Probability,'
		If @Loop = 1
			Set @S = @S +   ' SS.XCorr, SS.DeltaCn2,'
		If @Loop = 2
			Set @S = @S +   ' X.Normalized_Score, X.Hyperscore, X.Log_EValue, X.DeltaCn2,'

		Set @S = @S +   ' Pep.Charge_State, Pep.Scan_Number, PPM.Cleavage_State'
		Set @S = @S + ' FROM T_Analysis_Description TAD INNER JOIN '
		Set @S = @S +     ' T_Datasets DS ON TAD.Dataset_ID = DS.Dataset_ID INNER JOIN '
		Set @S = @S +     ' T_Peptides Pep ON TAD.Job = Pep.Analysis_ID INNER JOIN '
		If @Loop = 1
			Set @S = @S +     ' T_Score_Sequest SS ON Pep.Peptide_ID = SS.Peptide_ID INNER JOIN '
		If @Loop = 2
			Set @S = @S +     ' T_Score_XTandem X ON Pep.Peptide_ID = X.Peptide_ID INNER JOIN '
			
		Set @S = @S +     ' T_Peptide_to_Protein_Map PPM ON Pep.Peptide_ID = PPM.Peptide_ID INNER JOIN '
		Set @S = @S +     ' T_Proteins Pro ON PPM.Ref_ID = Pro.Ref_ID INNER JOIN '
		Set @S = @S +     ' T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID INNER JOIN '
		Set @S = @S +     ' T_Sequence S on Pep.Seq_ID = S.Seq_ID '
	
		If Len(@JobPeptideFilterTableName) > 0
			Set @S = @S + ' INNER JOIN [' + @JobPeptideFilterTableName + '] JPF ON Pep.Analysis_ID = JPF.Job AND Pep.Peptide = JPF.Peptide '

		Set @S = @S + ' WHERE PPM.Cleavage_State >= @CleavageStateMinimum AND'
		Set @S = @S +  ' TAD.job = @Job AND ('
		
		If @CleavageStateMinimum < 2
			Set @S = @S +    '(PPM.Cleavage_State = 2 AND '
			
		If @Loop = 1
		Begin
			Set @S = @S +    '(Pep.Charge_State = 1 AND SS.DeltaCn2 >= @MinDeltaCn AND SS.XCorr >= @MinXCorrFullyTrypticCharge1 OR'
			Set @S = @S +    ' Pep.Charge_State = 2 AND SS.DeltaCn2 >= @MinDeltaCn AND SS.XCorr >= @MinXCorrFullyTrypticCharge2 OR'
			Set @S = @S +    ' Pep.Charge_State >= 3 AND SS.DeltaCn2 >= @MinDeltaCn AND SS.XCorr >= @MinXCorrFullyTrypticCharge3)'
		End

		If @Loop = 2
		Begin
			Set @S = @S +    '(Pep.Charge_State = 1 AND X.DeltaCn2 >= @MinDeltaCn AND X.Normalized_Score >= @MinXCorrFullyTrypticCharge1 OR'
			Set @S = @S +    ' Pep.Charge_State = 2 AND X.DeltaCn2 >= @MinDeltaCn AND X.Normalized_Score >= @MinXCorrFullyTrypticCharge2 OR'
			Set @S = @S +    ' Pep.Charge_State >= 3 AND X.DeltaCn2 >= @MinDeltaCn AND X.Normalized_Score >= @MinXCorrFullyTrypticCharge3)'
		End

		If @CleavageStateMinimum < 2
		Begin
			Set @S = @S +    ') OR (PPM.Cleavage_State < 2 AND '

			If @Loop = 1
			Begin
				Set @S = @S +    '(Pep.Charge_State = 1 AND SS.DeltaCn2 >= @MinDeltaCn AND SS.XCorr >= @MinXCorrPartiallyTrypticCharge1 OR'
				Set @S = @S +    ' Pep.Charge_State = 2 AND SS.DeltaCn2 >= @MinDeltaCn AND SS.XCorr >= @MinXCorrPartiallyTrypticCharge2 OR'
				Set @S = @S +    ' Pep.Charge_State >= 3 AND SS.DeltaCn2 >= @MinDeltaCn AND SS.XCorr >= @MinXCorrPartiallyTrypticCharge3)'
			End

			If @Loop = 2
			Begin
				Set @S = @S +    '(Pep.Charge_State = 1 AND X.DeltaCn2 >= @MinDeltaCn AND X.Normalized_Score >= @MinXCorrPartiallyTrypticCharge1 OR'
				Set @S = @S +    ' Pep.Charge_State = 2 AND X.DeltaCn2 >= @MinDeltaCn AND X.Normalized_Score >= @MinXCorrPartiallyTrypticCharge2 OR'
				Set @S = @S +    ' Pep.Charge_State >= 3 AND X.DeltaCn2 >= @MinDeltaCn AND X.Normalized_Score >= @MinXCorrPartiallyTrypticCharge3)'
			End
			
			Set @S = @S +    ') '
		End
		
		Set @S = @S +  ' )'

		If @Loop = 1
			Set @InsertSqlPeptideHit = @S
		If @Loop = 2
			Set @InsertSqlXTPeptideHit = @S
	
	
		--------------------------------------------------------------
		-- Construct the @ColumnNameSql text
		--------------------------------------------------------------

		Set @S = ''
		Set @S = @S +   ' SIC_Job, Job, Dataset, Reference,' 
		Set @S = @S +   ' Cleavage_State, Seq_ID, Peptide,'
		Set @S = @S +   ' Monoisotopic_Mass, XCorr,'
		If @Loop = 2
			Set @S = @S +   ' Hyperscore, Log_Evalue,'
		Set @S = @S +   ' DeltaCn2, Charge_State,'
		Set @S = @S +   ' Discriminant, Peptide_Prophet_Prob,'
		Set @S = @S +   ' Optimal_Scan_Number, Elution_Time, '
		Set @S = @S +   ' Intensity, SN, FWHM, Area,'

		Set @S = @S +   ' Parent_Ion_Intensity,'
		Set @S = @S +   ' Parent_Ion_MZ,'
		Set @S = @S +   ' Peak_Baseline_Noise_Level,'
		Set @S = @S +   ' Peak_Baseline_Noise_StDev,'
		Set @S = @S +  ' Peak_Baseline_Points_Used,'

		Set @S = @S +   ' StatMoments_Area,'
		Set @S = @S +   ' CenterOfMass_Scan,'
		Set @S = @S +   ' Peak_StDev,'
		Set @S = @S +   ' Peak_Skew,'
		Set @S = @S +   ' Peak_KSStat,'
		Set @S = @S +   ' StatMoments_DataCount_Used,'
		Set @S = @S +   ' MSMS_Scan_Number'

		If @Loop = 1
			Set @ColumnNameSqlPeptideHit = @S
		If @Loop = 2
			Set @ColumnNameSqlXTPeptideHit = @S
		
		Set @Loop = @Loop + 1
	End
	
	-- Params string for sp_ExecuteSql
	Set @Params = '@Job int, @CleavageStateMinimum tinyint, @MinDeltaCn real, @MinXCorrFullyTrypticCharge1 real, @MinXCorrFullyTrypticCharge2 real, @MinXCorrFullyTrypticCharge3 real, @MinXCorrPartiallyTrypticCharge1 real, @MinXCorrPartiallyTrypticCharge2 real, @MinXCorrPartiallyTrypticCharge3 real'

	--------------------------------------------------------------
	-- Obtain the data for each job in #TmpJobList and place in #TmpPeptidesAndSICStats_Results
	--------------------------------------------------------------
	
	Declare @JobIsPeptideHit tinyint
	Declare @JobIsXTPeptideHit tinyint
	
	Set @Loop = 1
	While @Loop = 1
	Begin -- <a>
		SELECT TOP 1 @Job = Job, @ResultType = ResultType
		FROM #TmpJobList
		WHERE Job > @Job
		ORDER BY Job
			--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		If @myRowCount <> 1 Or @myError <> 0
			Set @Loop = 0
		Else
		Begin -- <b>
			-- Job has not yet been processed

			-- Examine @ResultType to determine which Sql to use
			If @ResultType = 'Peptide_Hit'
				Set @JobIsPeptideHit = 1
			Else
				Set @JobIsPeptideHit = 0

			If @ResultType = 'XT_Peptide_Hit'
				Set @JobIsXTPeptideHit = 1
			Else
				Set @JobIsXTPeptideHit = 0
				
			TRUNCATE TABLE #TmpPeptidesAndSICStats

			-- Populate the interim processing table with the data for @Job
			If @JobIsPeptideHit = 1
			Begin
				if @PreviewSql <> 0
					Print @InsertSqlPeptideHit
				else
					exec sp_ExecuteSql @InsertSqlPeptideHit,   @Params, @Job, @CleavageStateMinimum, @MinDeltaCn, @MinXCorrFullyTrypticCharge1, @MinXCorrFullyTrypticCharge2, @MinXCorrFullyTrypticCharge3, @MinXCorrPartiallyTrypticCharge1, @MinXCorrPartiallyTrypticCharge2, @MinXCorrPartiallyTrypticCharge3
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

			If @PreviewSql <> 0
			Begin
				Print @Params
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
			Begin -- <c>
				
				-- Update the interim processing table to include the DS_SIC data	
				UPDATE #TmpPeptidesAndSICStats
				SET Optimal_Peak_Apex_Scan_Number = DS_SIC.Optimal_Peak_Apex_Scan_Number, 
					Peak_Intensity = DS_SIC.Peak_Intensity, 
					Peak_SN_Ratio = DS_SIC.Peak_SN_Ratio, 
					FWHM_In_Scans = DS_SIC.FWHM_In_Scans,
					Peak_Area = DS_SIC.Peak_Area, 

					Parent_Ion_Intensity = DS_SIC.Parent_Ion_Intensity,
					Parent_Ion_MZ = DS_SIC.MZ,
					Peak_Baseline_Noise_Level = DS_SIC.Peak_Baseline_Noise_Level,
					Peak_Baseline_Noise_StDev = DS_SIC.Peak_Baseline_Noise_StDev,
					Peak_Baseline_Points_Used = DS_SIC.Peak_Baseline_Points_Used,
					StatMoments_Area = DS_SIC.StatMoments_Area,
					CenterOfMass_Scan = DS_SIC.CenterOfMass_Scan,
					Peak_StDev = DS_SIC.Peak_StDev,
					Peak_Skew = DS_SIC.Peak_Skew,
					Peak_KSStat = DS_SIC.Peak_KSStat,
					StatMoments_DataCount_Used = DS_SIC.StatMoments_DataCount_Used

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
				Begin -- <d>
					--------------------------------------------------------------
					-- Group By the metric indicated by @MaxValueSelectionMode
					-- First, need to flag the row with the highest given value for each Seq_ID
					--------------------------------------------------------------
					
					Set @UseValueMinimum = 1
						
					-- Define the Selection Field based on @MaxValueSelectionMode
					-- Default to use Peak_Area
					Set @SelectionField = 'Peak_Area'
					
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
							Set @SelectionField = 'Log_Evalue'
					End
				
					Set @S = ''
					Set @S = @S + ' UPDATE #TmpPeptidesAndSICStats'
					Set @S = @S + ' SET UseValue = 1'
					Set @S = @S + ' FROM #TmpPeptidesAndSICStats S INNER JOIN'
					Set @S = @S +    ' ( SELECT MIN(S.Unique_Row_ID) AS Unique_Row_ID_Min'
					Set @S = @S +      ' FROM #TmpPeptidesAndSICStats S INNER JOIN'
					Set @S = @S +       ' ( SELECT SIC_Job, Seq_ID, MAX(' + @SelectionField + ') AS Value_Max'
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
					Set @S = @S +       ' S.' + @SelectionField + ' = LookupQ.Value_Max'
					Set @S = @S +      ' GROUP BY S.Seq_ID'
					If @GroupByChargeState <> 0
						Set @S = @S +				', S.Charge_State'
					Set @S = @S +    ' ) UniqueRowQ ON'
					Set @S = @S +    ' S.Unique_Row_ID = UniqueRowQ.Unique_Row_ID_Min'
					
					exec sp_ExecuteSql @S
					--
					SELECT @myRowCount = @@rowcount, @myError = @@error							
				
				End -- </d>
			End -- </c>

			--------------------------------------------------------------
			-- Append the desired data to #TmpPeptidesAndSICStats_Results
			-- We have to use dynamic SQL here because the table may not contain
			--  columns Hyperscore or Log_Evalue
			--------------------------------------------------------------
			--
			Set @S = ''
			Set @S = @S + ' INSERT INTO #TmpPeptidesAndSICStats_Results ('
			If @JobIsXTPeptideHit = 1
				Set @S = @S + @ColumnNameSqlXTPeptideHit
			Else
				Set @S = @S + @ColumnNameSqlPeptideHit
				
			Set @S = @S + ' )'
			Set @S = @S + ' SELECT S.SIC_Job, S.Job, S.Dataset, S.Reference,'
			Set @S = @S +   ' S.Cleavage_State, S.Seq_ID, S.Peptide,'
			Set @S = @S +   ' S.Monoisotopic_Mass, S.XCorr,'
			If @JobIsXTPeptideHit = 1
				Set @S = @S +   ' S.Hyperscore,S.Log_Evalue,'

			Set @S = @S +   ' S.DeltaCn2, S.Charge_State,'
			Set @S = @S +   ' S.DiscriminantScoreNorm, S.Peptide_Prophet_Probability,'
			Set @S = @S +   ' S.Optimal_Peak_Apex_Scan_Number, DS_Scans.Scan_Time,'
			Set @S = @S +   ' S.Peak_Intensity, S.Peak_SN_Ratio, S.FWHM_In_Scans, S.Peak_Area,'

			Set @S = @S +   ' Parent_Ion_Intensity,'
			Set @S = @S +   ' Parent_Ion_MZ,'
			Set @S = @S +   ' Peak_Baseline_Noise_Level,'
			Set @S = @S +   ' Peak_Baseline_Noise_StDev,'
			Set @S = @S +   ' Peak_Baseline_Points_Used,'

			Set @S = @S +   ' StatMoments_Area,'
			Set @S = @S +   ' CenterOfMass_Scan,'
			Set @S = @S +   ' Peak_StDev,'
			Set @S = @S +   ' Peak_Skew,'
			Set @S = @S +   ' Peak_KSStat,'
			Set @S = @S +   ' StatMoments_DataCount_Used,'
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
			Begin
				-- Update the data in #TmpPeptidesAndSICStats_Results for this job to reflect the maximum scores for each peptide

				If @JobIsPeptideHit = 1
					Set @SelectionField = 'XCorr'

				If @JobIsXTPeptideHit = 1
					Set @SelectionField = 'Hyperscore'
			
				If @MaxValueSelectionMode < 3
				Begin
					Set @S = ''
					Set @S = @S + ' UPDATE #TmpPeptidesAndSICStats_Results'
					Set @S = @S + ' SET XCorr = MaxValuesQ.XCorr,'
					Set @S = @S +     ' DeltaCn2 = MaxValuesQ.DeltaCn2,'
					Set @S = @S +     ' Charge_State = MaxValuesQ.Charge_State,'
					Set @S = @S +     ' MSMS_Scan_Number = MaxValuesQ.Scan_Number'
					If @JobIsXTPeptideHit = 1
					Begin
						Set @S = @S + ' , Hyperscore = MaxValuesQ.Hyperscore'
						Set @S = @S + ' , Log_EValue = MaxValuesQ.Log_EValue'
					End
					Set @S = @S + ' FROM #TmpPeptidesAndSICStats_Results Target INNER JOIN'
					Set @S = @S + ' ( SELECT S.SIC_Job, S.Seq_ID, S.XCorr, S.DeltaCn2, S.Charge_State, S.Scan_Number'
					If @JobIsXTPeptideHit = 1
						Set @S = @S +    ' , S.Hyperscore, S.Log_EValue'

					Set @S = @S +   ' FROM #TmpPeptidesAndSICStats S INNER JOIN'
					Set @S = @S +      ' ( SELECT MIN(S.Unique_Row_ID) AS Unique_Row_ID_Min'
					Set @S = @S +        ' FROM #TmpPeptidesAndSICStats S INNER JOIN'
					Set @S = @S +         ' ( SELECT SIC_Job, Seq_ID, MAX(' + @SelectionField + ') AS Value_Max'
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
					Set @S = @S +         ' S.' + @SelectionField + ' = LookupQ.Value_Max'
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
				End

				Set @S = ''
				Set @S = @S + ' UPDATE #TmpPeptidesAndSICStats_Results'
				Set @S = @S + ' SET Discriminant = MaxValuesQ.DiscriminantScoreNorm,'
				Set @S = @S +     ' Peptide_Prophet_Prob = MaxValuesQ.Peptide_Prophet_Probability'
				Set @S = @S + ' FROM #TmpPeptidesAndSICStats_Results Target INNER JOIN'
				Set @S = @S + ' ( SELECT SIC_Job, Seq_ID,'
				Set @S = @S +          ' MAX(DiscriminantScoreNorm) AS DiscriminantScoreNorm,'
				Set @S = @S +          ' MAX(Peptide_Prophet_Probability) AS Peptide_Prophet_Probability'
				If @GroupByChargeState <> 0
					Set @S = @S +      ', Charge_State'
				Set @S = @S +   ' FROM #TmpPeptidesAndSICStats'
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
					
			End
			
		End -- </b>
	End -- </a>


	-- Query #TmpPeptidesAndSICStats_Results to obtain the data

	If @XTPeptideHit = 1
		Set @S = 'SELECT ' + @ColumnNameSqlXTPeptideHit
	Else
		Set @S = 'SELECT ' + @ColumnNameSqlPeptideHit

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
GRANT EXECUTE ON [dbo].[GetPeptidesAndSICStats] TO [DMS_SP_User]
GO
GRANT EXECUTE ON [dbo].[GetPeptidesAndSICStats] TO [MTUser]
GO
