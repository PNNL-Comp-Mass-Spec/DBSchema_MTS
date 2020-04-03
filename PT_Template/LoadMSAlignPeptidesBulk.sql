/****** Object:  StoredProcedure [dbo].[LoadMSAlignPeptidesBulk] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.LoadMSAlignPeptidesBulk
/****************************************************
**
**	Desc:
**		Load peptides from MSAlign synopsis file into peptides table
**		for given analysis job using bulk loading techniques
**
**		Note: This routine will not load peptides with score values
**			  below minimum thresholds (as defined by @FilterSetID)
**			  In particular, filters on PValue and FDR
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	12/04/2012 mem - Initial version
**			12/06/2012 mem - Expanded @message to varchar(1024)
**			02/26/2013 mem - Expanded Mass_Correction_Tag in #Tmp_Peptide_ModSummary to varchar(128)
**			03/12/2014 mem - No longer checking for proteins with long protein names
**			08/31/2015 mem - Add support for MSAlign synopsis files with 22 columns
**          04/09/2020 mem - Expand Mass_Correction_Tag to varchar(32)
**
*****************************************************/
(
	@PeptideSynFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_MSAlign_syn.txt',
	@PeptideResultToSeqMapFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_ResultToSeqMap.txt',
	@PeptideSeqInfoFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_SeqInfo.txt',
	@PeptideSeqModDetailsFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_ModDetails.txt',
	@PeptideSeqToProteinMapFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_SeqToProteinMap.txt',
	@MSGFResultsFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_MSAlign_syn_MSGF.txt',
	@Job int,
	@FilterSetID int,
	@LineCountToSkip int=1,
	@SynFileColCount int,
	@SynFileHeader varchar(2048),
	@UpdateExistingData tinyint,
	@numLoaded int=0 output,
	@numSkipped int=0 output,
	@SeqCandidateFilesFound tinyint=0 output,
	@MSGFFileFound tinyint=0 output,
	@message varchar(1024)='' output,
	@infoOnly tinyint = 0
)
As
	Set NoCount On

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @UsingPhysicalTempTables tinyint
	-- Set the following to 1 when using actual tables to hold the temporary data while debugging
	set @UsingPhysicalTempTables = 0

	set @numLoaded = 0
	set @numSkipped = 0
	set @SeqCandidateFilesFound = 0
	set @MSGFFileFound = 0
	set @message = ''
	Set @infoOnly = IsNull(@infoOnly, 0)

	Set @SynFileColCount = IsNull(@SynFileColCount, 0)
	Set @SynFileHeader = IsNull(@SynFileHeader, '')

	declare @jobStr varchar(12)
	set @jobStr = convert(varchar(12), @Job)

	declare @Sql varchar(2048)
	declare @W varchar(1024)

	declare @UnfilteredCountLoaded int
	set @UnfilteredCountLoaded = 0

	declare @MatchCount int

	declare @RowCountTotal int
	declare @RowCountNull int
	declare @RowCountNullCharge5OrLess int
	declare @MessageType varchar(32)

	declare @LongProteinNameCount int
	set @LongProteinNameCount = 0

	declare @UseMSGFFilter tinyint
	declare @UseMSAlignPValueFilter tinyint
	declare @UseMSAlignFDRFilter tinyint

	declare @LogLevel int
	declare @LogMessage varchar(512)

	Declare @fileExists tinyint
	Declare @result int

	Declare @CreateDebugTables tinyint = 0

	-----------------------------------------------
	-- Lookup the logging level from T_Process_Step_Control
	-----------------------------------------------

	Set @LogLevel = 1
	SELECT @LogLevel = enabled
	FROM T_Process_Step_Control
	WHERE (Processing_Step_Name = 'LogLevel')
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	Set @LogMessage = 'Loading MSAlign results for Job ' + @jobStr + '; create temporary tables'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

	-----------------------------------------------
	-- Drop physical tables if required
	-----------------------------------------------

	If @UsingPhysicalTempTables = 1
	Begin
		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Peptide_Filter_Flags]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Peptide_Filter_Flags]

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Peptide_Import]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Peptide_Import]

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Peptide_Import_Unfiltered]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Peptide_Import_Unfiltered]

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Unique_Records]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Unique_Records]
	End

	-----------------------------------------------
	-- Create temporary table to hold contents
	--  of MSAlign synopsis file (_MSAlign_syn.txt)
	-- Additional columns may get added to this table
	-----------------------------------------------
	--
	Declare @SynFileVersion varchar(64)
	Set @SynFileVersion = ''

	If @SynFileColCount = 0
	Begin
		Set @message = '0 peptides were loaded for job ' + @jobStr + ' (synopsis file is empty)'
		set @myError = 60002	-- Note that this error code is used in SP LoadResultsForAvailableAnalyses; do not change
		Goto Done
	End

	If @SynFileColCount = 20
	Begin
		Set @SynFileVersion = '2012'
	End

	If @SynFileColCount = 22
	Begin
		Set @SynFileVersion = '2013'
	End

	If @SynFileVersion = ''
	Begin
		-- Unrecognized version
		Set @myError = 52005
		Set @message = 'Unrecognized Synopsis file format for Job ' + @jobStr
		Set @message = @message + '; synopsis file contains ' + convert(varchar(12), @SynFileColCount) + ' columns (Expecting 20 columns)'
		goto Done
	End

	-- Create table #Tmp_Peptide_Import
	--
	CREATE TABLE #Tmp_Peptide_Import (
		Result_ID int NOT NULL ,
		Scan_Number int NOT NULL ,
		Prsm_ID int NULL ,
		Spectrum_ID int NULL ,
		Charge_State smallint NOT NULL ,
		PrecursorMZ float NULL ,
		DelM real NULL ,
		DelM_PPM real NULL ,
		MH float NULL ,
		Peptide varchar(max) NULL ,				-- Peptides longer than 850 characters will truncated prior to storing in T_Peptides
		Protein varchar(250) NULL ,
		Protein_Mass real NULL ,
		Unexpected_Mod_Count smallint NULL ,
		Peak_Count smallint NULL ,
		Matched_Peak_Count smallint NULL ,
		Matched_Fragment_Ion_Count smallint NULL ,
		PValue real NULL ,
		Rank_PValue int NOT NULL ,
		EValue real NULL ,
		FDR real NULL
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #Tmp_Peptide_Import for job ' + @jobStr
		goto Done
	end

	-- Add additional columns
	If @SynFileVersion IN ('2013')
	Begin
		-- Add columns that were added for MSAlign_Histone
		-- (these columns are blank for MSAlign results)
		ALTER Table #Tmp_Peptide_Import ADD
			Species_ID varchar(24) NULL,
			FragMethod varchar(24) NULL
	End

	CREATE CLUSTERED INDEX #IX_Tmp_Peptide_Import_Result_ID ON #Tmp_Peptide_Import (Result_ID)
	CREATE INDEX #IX_Tmp_Peptide_Import_Scan_Number ON #Tmp_Peptide_Import (Scan_Number)


	-----------------------------------------------
	-- Create a table that will match up entries
	-- in #Tmp_Peptide_Import that are nearly identical,
	--  with the only difference being protein name
	-- Entries have matching:
	--	Scan, Charge, PValue, and Peptide
	-----------------------------------------------
	CREATE TABLE #Tmp_Peptide_Import_MatchedEntries (
		Result_ID1 int NOT NULL,
		Result_ID2 int NOT NULL
	)

	CREATE CLUSTERED INDEX #IX_Tmp_Peptide_Import_MatchedEntries ON #Tmp_Peptide_Import_MatchedEntries (Result_ID2)

	-----------------------------------------------
	-- Also create a table for holding flags of whether or not
	-- the peptides pass the import filter
	-----------------------------------------------
	CREATE TABLE #Tmp_Peptide_Filter_Flags (
		Result_ID int NOT NULL,
		Valid tinyint NOT NULL
	)

	CREATE CLUSTERED INDEX #IX_Tmp_Peptide_Filter_Flags_Result_ID ON #Tmp_Peptide_Filter_Flags (Result_ID)


	-----------------------------------------------
	-- Bulk load contents of synopsis file into temporary table
	-----------------------------------------------
	--
	Set @LogMessage = 'Bulk load contents of _MSAlign_syn.txt file into temporary table; source path: ' + @PeptideSynFilePath
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

	declare @c nvarchar(2048)

	Set @c = 'BULK INSERT #Tmp_Peptide_Import FROM ' + '''' + @PeptideSynFilePath + ''' WITH (FIRSTROW = ' + Convert(varchar(9), @LineCountToSkip+1) + ')'
	exec @myError = sp_executesql @c
	--
	if @myError <> 0
	begin
		set @message = 'Problem executing bulk insert for job ' + @jobStr
		Set @myError = 50001
		goto Done
	end

	-- Future: add missing columns
	If @SynFileVersion IN ('Future_Version')
	Begin
		-- Add FDR columns
		ALTER Table #Tmp_Peptide_Import ADD
			FutureColumn real NULL
	End

	-----------------------------------------------
	-- Populate @UnfilteredCountLoaded; this will be compared against
	-- the ResultToSeqMap count loaded to confirm that they match
	-----------------------------------------------
	SELECT @UnfilteredCountLoaded = Count(*)
	FROM #Tmp_Peptide_Import
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


	Set @LogMessage = 'Load complete; loaded ' + Convert(varchar(12), @UnfilteredCountLoaded) + ' unfiltered peptides'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

	-----------------------------------------------
	-- If @UnfilteredCountLoaded = 0, then no need to continue
	-----------------------------------------------
	If @UnfilteredCountLoaded = 0
	Begin
		Set @numLoaded = 0
		Goto Done
	End

	-----------------------------------------------
	-- Create temporary tables to hold contents
	-- of the SeqInfo related files
	-----------------------------------------------
	--
	If @UsingPhysicalTempTables = 1
	Begin
		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Peptide_ResultToSeqMap]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Peptide_ResultToSeqMap]

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Peptide_SeqInfo]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Peptide_SeqInfo]

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Peptide_ModDetails]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Peptide_ModDetails]

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Peptide_ModSummary]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Peptide_ModSummary]

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Peptide_SeqToProteinMap]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Peptide_SeqToProteinMap]

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_MSGF_Results]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_MSGF_Results]
	End


	-- Table for contents of the ResultToSeqMapFile
	--
	CREATE TABLE #Tmp_Peptide_ResultToSeqMap (
		Result_ID int NOT NULL,
		Seq_ID_Local int NOT NULL
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #Tmp_Peptide_ResultToSeqMap for job ' + @jobStr
		goto Done
	end

	CREATE CLUSTERED INDEX #IX_Tmp_Peptide_ResultToSeqMap_Result_ID ON #Tmp_Peptide_ResultToSeqMap (Result_ID)


	-- Table for contents of the SeqInfo file
	--
	--	 Unique_Seq_ID				Sequence ID unique to this job, aka Seq_ID_Local
	--	 Mod_Count
	--	 Mod_Description
	--	 Monoisotopic_Mass

	CREATE TABLE #Tmp_Peptide_SeqInfo (
		Seq_ID_Local int NOT NULL ,
		Mod_Count smallint NOT NULL ,
		Mod_Description varchar(2048) NULL ,
		Monoisotopic_Mass float NOT NULL
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #Tmp_Peptide_SeqInfo for job ' + @jobStr
		goto Done
	end

	CREATE CLUSTERED INDEX #IX_Tmp_Peptide_SeqInfo_Seq_ID ON #Tmp_Peptide_SeqInfo (Seq_ID_Local)


	-- Table for contents of the ModDetails file
	--
	CREATE TABLE #Tmp_Peptide_ModDetails (
		Seq_ID_Local int NOT NULL ,
		Mass_Correction_Tag varchar(128) NOT NULL ,			-- Note: The mass correction tags are limited to 32 characters when storing in T_Seq_Candidate_ModDetails
		[Position] int NOT NULL
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #Tmp_Peptide_ModDetails for job ' + @jobStr
		goto Done
	end

	CREATE CLUSTERED INDEX #IX_Tmp_Peptide_ModDetails_Seq_ID ON #Tmp_Peptide_ModDetails (Seq_ID_Local)


	-- Table for contents of the ModSummary file
	--
	CREATE TABLE #Tmp_Peptide_ModSummary (
		Modification_Symbol varchar(4) NULL,
		Modification_Mass real NOT NULL,
		Target_Residues varchar(64) NULL,
		Modification_Type varchar(4) NOT NULL,
		Mass_Correction_Tag varchar(128) NOT NULL,					-- Note: The mass correction tags are limited to 32 characters when storing in T_Seq_Candidate_ModSummary
		Occurrence_Count int NULL
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #Tmp_Peptide_ModSummary for job ' + @jobStr
		goto Done
	end

	CREATE CLUSTERED INDEX #IX_Tmp_Peptide_ModDetails_Seq_ID ON #Tmp_Peptide_ModSummary (Mass_Correction_Tag)


	-- Table for contents of the SeqToProteinMap file
	--
	--	 Unique_Seq_ID						Sequence ID unique to this job, aka Seq_ID_Local
	--	 Cleavage_State
	--	 Terminus_State
	--	 Protein_Name
	--	 Protein_Expectation_Value_Log(e)	Base-10 log of the protein E-value (only used by XTandem)
	--	 Protein Intensity_Log(I)			Base-10 log of the protein intensity; simply the sum of the intensity values of all peptide's found for this protein in this job (only used by XTandem)

	CREATE TABLE #Tmp_Peptide_SeqToProteinMap (
		Seq_ID_Local int NOT NULL ,
		Cleavage_State smallint NOT NULL ,
		Terminus_State smallint NOT NULL ,
		Reference varchar(255) NULL ,
		Protein_Log_EValue real NULL ,
		Protein_Log_Intensity real NULL
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #Tmp_Peptide_SeqToProteinMap for job ' + @jobStr
		goto Done
	end

	CREATE CLUSTERED INDEX #IX_Tmp_Peptide_SeqToProteinMap_Seq_ID ON #Tmp_Peptide_SeqToProteinMap (Seq_ID_Local)


	-----------------------------------------------
	-- Create a temporary table to hold contents
	-- of the MSGF results file (if it exists)
	-----------------------------------------------
	CREATE TABLE #Tmp_MSGF_Results (
		Result_ID int NOT NULL,						-- Corresponds to #Tmp_Peptide_Import.Result_ID
		Scan int NOT NULL,
		Charge smallint NOT NULL,
		Protein varchar(255) NULL,
		Peptide varchar(max) NOT NULL,
		SpecProb real NULL,
		SpecProbNote varchar(512) NULL
	)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #Tmp_MSGF_Results for job ' + @jobStr
		goto Done
	end

	-----------------------------------------------
	-- Call LoadMSGFResultsOneJob to load
	-- the MSGF results file (if it exists)
	-----------------------------------------------
	Declare @MSGFCountLoaded int
	Set @MSGFCountLoaded = 0

	Set @LogMessage = 'Bulk load contents of MSGF file into temporary table; source path: ' + @MSGFResultsFilePath
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

	exec @myError = LoadMSGFResultsOneJob @job, @MSGFResultsFilePath, @MSGFCountLoaded output, @message output, @RaiseErrorIfFileNotFound=0

	Set @LogMessage = 'Load complete; loaded ' + Convert(varchar(12), @MSGFCountLoaded) + ' entries'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

	if @myError <> 0
	Begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling LoadMSGFResultsOneJob for job ' + @jobStr
		Goto Done
	End

	If @infoOnly <> 0
	Begin
		SELECT TOP 10 '#Tmp_Peptide_Import, 10 rows' AS Source, * FROM #Tmp_Peptide_Import
		SELECT TOP 10 '#Tmp_MSGF_Results, 10 rows' AS Source, * FROM #Tmp_MSGF_Results
	End

	-----------------------------------------------
	-- Call LoadSeqInfoAndModsPart1 to load the SeqInfo related files if they exist
	-- If they do not exist, then @ResultToSeqMapCountLoaded will be 0;
	--  if an error occurs, then @result will be non-zero
	-----------------------------------------------
	--
	Declare @ResultToSeqMapCountLoaded int
	Declare @ExpectedResultToSeqMapCount int
	Declare @RaiseErrorIfSeqInfoFilesNotFound tinyint
	Set @ResultToSeqMapCountLoaded = 0

	If @infoOnly = 0
		Set @RaiseErrorIfSeqInfoFilesNotFound = 1
	Else
		Set @RaiseErrorIfSeqInfoFilesNotFound = 0

	exec @myError = LoadSeqInfoAndModsPart1
						@PeptideResultToSeqMapFilePath,
						@PeptideSeqInfoFilePath,
						@PeptideSeqModDetailsFilePath,
						@PeptideSeqToProteinMapFilePath,
						@job,
						@RaiseErrorIfSeqInfoFilesNotFound,
						@ResultToSeqMapCountLoaded output,
						@message output,
						@LoadModSummaryFile=1

	if @myError <> 0
	Begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling LoadSeqInfoAndModsPart1 for job ' + @jobStr
		Goto Done
	End

	If @ResultToSeqMapCountLoaded > 0
	Begin
		-- Query #Tmp_Peptide_Import to determine the number of entries that should be present in #Tmp_Peptide_ResultToSeqMap
		-- The Case Statement removes the prefix and suffix residues, changing the peptide sequence from K.SGYYDWHK.R to SGYYDWHK
		Set @ExpectedResultToSeqMapCount = 0
		SELECT @ExpectedResultToSeqMapCount = COUNT(*)
		FROM ( SELECT DISTINCT Scan_Number,
		                       Charge_State,
		                       MH,
		                       CASE WHEN Len(Peptide) > 4
		                            THEN Substring(Peptide, 3, Len(Peptide) - 4)
		                            ELSE Peptide END AS Peptide
		       FROM #Tmp_Peptide_Import
		     ) LookupQ

		If @ResultToSeqMapCountLoaded < @ExpectedResultToSeqMapCount
		Begin
			Set @message = 'Row count in the _ResultToSeqMap.txt file is less than the expected unique row count determined for the MSAlign _syn.txt file for job ' + @jobStr + ' (' + Convert(varchar(12), @ResultToSeqMapCountLoaded) + ' vs. ' + Convert(varchar(12), @ExpectedResultToSeqMapCount) + ')'

			-- @ResultToSeqMapCountLoaded is non-zero; record this as a warning, but flag it as type 'Error' so it shows up in the daily e-mail
			Set @message = 'Warning: ' + @message
			execute PostLogEntry 'Error', @message, 'LoadMSAlignPeptidesBulk'
			Set @message = ''
		End

		If @infoOnly <> 0
		Begin
			SELECT TOP 10 '#Tmp_Peptide_ResultToSeqMap, 10 rows' AS Source, * FROM #Tmp_Peptide_ResultToSeqMap
			SELECT TOP 10 '#Tmp_Peptide_SeqInfo, 10 rows' AS Source, * FROM #Tmp_Peptide_SeqInfo
			SELECT TOP 10 '#Tmp_Peptide_ModDetails, 10 rows' AS Source, * FROM #Tmp_Peptide_ModDetails
			SELECT TOP 10 '#Tmp_Peptide_ModSummary, 10 rows' AS Source, * FROM #Tmp_Peptide_ModSummary
			SELECT TOP 10 '#Tmp_Peptide_SeqToProteinMap, 10 rows' AS Source, * FROM #Tmp_Peptide_SeqToProteinMap
		End

	End


	-----------------------------------------------
	-- If the SeqInfo related files were not found, then we cannot continue
	-- LoadSeqInfoAndModsPart1 should have set @myError to a non-zero value and
	--  therefore jumped to Done in this SP.  Check @ResultToSeqMapCountLoaded now to validate this
	-----------------------------------------------
	If @ResultToSeqMapCountLoaded <= 0
	Begin
		Set @myError = 50002
		Set @message = 'The _ResultToSeqMap.txt file was empty for MSAlign job ' + @jobStr + '; cannot continue'
		Goto Done
	End
	Else
		Set @SeqCandidateFilesFound = 1

	-----------------------------------------------
	-- Make sure all peptides in #Tmp_Peptide_Import have
	-- an MH defined; if they don't, assign a value of 0
	-----------------------------------------------
	UPDATE #Tmp_Peptide_Import
	SET MH = 0
	WHERE MH IS NULL
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myRowCount > 0
	Begin
		Set @message = 'Newly imported peptides found with Null MH values for job ' + @jobStr + ' (' + convert(varchar(11), @myRowCount) + ' peptides)'
		execute PostLogEntry 'Error', @message, 'LoadMSAlignPeptidesBulk'
		Set @message = ''
	End

	-----------------------------------------------
	-- Make sure all peptides in #Tmp_Peptide_Import have
	-- PValue and FDR defined
	-----------------------------------------------
	UPDATE #Tmp_Peptide_Import
	SET PValue = 1
	WHERE PValue IS NULL
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myRowCount > 0
	Begin
		Set @message = 'Newly imported peptides found with Null PValues for job ' + @jobStr + ' (' + convert(varchar(11), @myRowCount) + ' peptides)'
		execute PostLogEntry 'Error', @message, 'LoadMSAlignPeptidesBulk'
		Set @message = ''
	End

	UPDATE #Tmp_Peptide_Import
	SET FDR = 1
	WHERE FDR IS NULL
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myRowCount > 0
	Begin
		Set @message = 'Newly imported peptides found with Null FDR for job ' + @jobStr + ' (' + convert(varchar(11), @myRowCount) + ' peptides)'
		execute PostLogEntry 'Error', @message, 'LoadMSAlignPeptidesBulk'
		Set @message = ''
	End

	If @infoOnly <> 0
	Begin
		SELECT TOP 1000 '#Tmp_Peptide_Import, 1000 rows' AS Source, * FROM #Tmp_Peptide_Import
	End

	-----------------------------------------------------------
	-- Define the filter threshold values
	-----------------------------------------------------------
	--
	Declare @CriteriaGroupStart int,
			@CriteriaGroupMatch int,
			@SpectrumCountComparison varchar(2),		-- Not used in this SP
			@SpectrumCountThreshold int,				-- Not used in this SP
			@ChargeStateComparison varchar(2),
			@ChargeStateThreshold tinyint,
			@HighNormalizedScoreComparison varchar(2),	-- Not used in this SP
			@HighNormalizedScoreThreshold float,		-- Not used in this SP
			@CleavageStateComparison varchar(2),
			@CleavageStateThreshold tinyint,
			@PeptideLengthComparison varchar(2),		-- Not used in this SP
			@PeptideLengthThreshold smallint,			-- Not used in this SP
			@MassComparison varchar(2),
			@MassThreshold float,
			@DeltaCnComparison varchar(2),				-- Not used in this SP
			@DeltaCnThreshold float,					-- Not used in this SP
			@DeltaCn2Comparison varchar(2),				-- Not used in this SP
			@DeltaCn2Threshold float,					-- Not used in this SP
			@DiscriminantScoreComparison varchar(2),	-- Not used in this SP
			@DiscriminantScoreThreshold float,			-- Not used in this SP
			@NETDifferenceAbsoluteComparison varchar(2),-- Not used in this SP
			@NETDifferenceAbsoluteThreshold float,		-- Not used in this SP
			@DiscriminantInitialFilterComparison varchar(2),	-- Not used in this SP
			@DiscriminantInitialFilterThreshold float,			-- Not used in this SP

			@ProteinCountComparison varchar(2),			-- Not used in this SP
			@ProteinCountThreshold int,					-- Not used in this SP
			@TerminusStateComparison varchar(2),
			@TerminusStateThreshold tinyint,

			@XTandemHyperscoreComparison varchar(2),	-- Not used in this SP
			@XTandemHyperscoreThreshold real,			-- Not used in this SP
			@XTandemLogEValueComparison varchar(2),		-- Not used in this SP
			@XTandemLogEValueThreshold real,			-- Not used in this SP

			@PeptideProphetComparison varchar(2),		-- Not used in this SP
			@PeptideProphetThreshold float,				-- Not used in this SP

			@RankScoreComparison varchar(2),
			@RankScoreThreshold smallint,

			@MSGFSpecProbComparison varchar(2),			-- Used for Sequest, X!Tandem, or Inspect results
			@MSGFSpecProbThreshold real,

			@MSAlignPValueComparison varchar(2),		-- Used by MSAlign
			@MSAlignPValueThreshold real,

			@MSAlignFDRComparison varchar(2),			-- Used by MSAlign
			@MSAlignFDRThreshold real


	If IsNull(@FilterSetID, 0) = 0
	Begin
		-- Do not filter the peptides
		UPDATE #Tmp_Peptide_Filter_Flags
		SET Valid = 1

	End
	Else
	Begin -- <Filter>

		-----------------------------------------------------------
		-- Validate that @FilterSetID is defined in V_Filter_Sets_Import
		-- Do this by calling GetThresholdsForFilterSet and examining @CriteriaGroupMatch
		-----------------------------------------------------------
		--
		Set @CriteriaGroupStart = 0
		Set @CriteriaGroupMatch = 0
		Exec @myError = GetThresholdsForFilterSet @FilterSetID, @CriteriaGroupStart, @CriteriaGroupMatch OUTPUT, @message OUTPUT,
										@SpectrumCountComparison OUTPUT,@SpectrumCountThreshold OUTPUT,
										@ChargeStateComparison OUTPUT,@ChargeStateThreshold OUTPUT,
										@HighNormalizedScoreComparison OUTPUT,@HighNormalizedScoreThreshold OUTPUT,
										@CleavageStateComparison OUTPUT,@CleavageStateThreshold OUTPUT,
										@PeptideLengthComparison OUTPUT,@PeptideLengthThreshold OUTPUT,
										@MassComparison OUTPUT,@MassThreshold OUTPUT,
										@DeltaCnComparison OUTPUT,@DeltaCnThreshold OUTPUT,
										@DeltaCn2Comparison OUTPUT, @DeltaCn2Threshold OUTPUT,
										@DiscriminantScoreComparison OUTPUT, @DiscriminantScoreThreshold OUTPUT,
										@NETDifferenceAbsoluteComparison OUTPUT, @NETDifferenceAbsoluteThreshold OUTPUT,
										@DiscriminantInitialFilterComparison OUTPUT, @DiscriminantInitialFilterThreshold OUTPUT,
										@ProteinCountComparison OUTPUT, @ProteinCountThreshold OUTPUT,
										@TerminusStateComparison OUTPUT, @TerminusStateThreshold OUTPUT,
										@XTandemHyperscoreComparison OUTPUT, @XTandemHyperscoreThreshold OUTPUT,
										@XTandemLogEValueComparison OUTPUT, @XTandemLogEValueThreshold OUTPUT,
										@PeptideProphetComparison OUTPUT, @PeptideProphetThreshold OUTPUT,
										@RankScoreComparison OUTPUT, @RankScoreThreshold OUTPUT,
										@MSGFSpecProbComparison = @MSGFSpecProbComparison OUTPUT, @MSGFSpecProbThreshold = @MSGFSpecProbThreshold OUTPUT,
										@MSAlignPValueComparison = @MSAlignPValueComparison OUTPUT, @MSAlignPValueThreshold = @MSAlignPValueThreshold OUTPUT,
										@MSAlignFDRComparison = @MSAlignFDRComparison OUTPUT, @MSAlignFDRThreshold = @MSAlignFDRThreshold OUTPUT


		if @myError <> 0
		begin
			if len(@message) = 0
				set @message = 'Could not validate filter set ID ' + Convert(varchar(11), @FilterSetID) + ' using GetThresholdsForFilterSet'
			goto Done
		end

		if @CriteriaGroupMatch = 0
		begin
			set @message = 'Filter set ID ' + Convert(varchar(11), @FilterSetID) + ' not found using GetThresholdsForFilterSet'
			set @myError = 50003
			goto Done
		end

		-----------------------------------------------
		-- Populate #Tmp_Peptide_Filter_Flags
		-----------------------------------------------
		--
		Set @LogMessage = 'Populate #Tmp_Peptide_Filter_Flags using #Tmp_Peptide_Import'
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

		INSERT INTO #Tmp_Peptide_Filter_Flags (Result_ID, Valid)
		SELECT Result_ID, 0
		FROM #Tmp_Peptide_Import
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		Set @LogMessage = 'Populated #Tmp_Peptide_Filter_Flags with ' + Convert(varchar(12), @myRowCount) + ' rows'
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

		-----------------------------------------------
		-- Mark peptides that pass the thresholds
		-----------------------------------------------

		While @CriteriaGroupMatch > 0
		Begin -- <CriteriaGroupMatch>

			Set @UseMSGFFilter = 0
			Set @UseMSAlignPValueFilter = 0
			Set @UseMSAlignFDRFilter = 0

			If @MSGFCountLoaded > 0
			Begin
				If @MSGFSpecProbComparison IN ('<', '<=') AND @MSGFSpecProbThreshold < 1
					Set @UseMSGFFilter = 1
			End

			If @MSAlignPValueComparison IN ('<', '<=') AND @MSAlignPValueThreshold < 1
				Set @UseMSAlignPValueFilter = 1

			If @MSAlignFDRComparison IN ('<', '<=') AND @MSAlignFDRThreshold < 1
				Set @UseMSAlignFDRFilter = 1

			-- Construct the Sql Update Query
			--
			Set @Sql = ''
			Set @Sql = @Sql + ' UPDATE #Tmp_Peptide_Filter_Flags'
			Set @Sql = @Sql + ' SET Valid = 1'
			Set @Sql = @Sql + ' FROM #Tmp_Peptide_Filter_Flags TFF INNER JOIN'
			Set @Sql = @Sql +   ' ( SELECT TPI.Result_ID'
			Set @Sql = @Sql +     ' FROM #Tmp_Peptide_Import TPI INNER JOIN'
			Set @Sql = @Sql +          ' #Tmp_Peptide_ResultToSeqMap RTSM ON TPI.Result_ID = RTSM.Result_ID INNER JOIN'
			Set @Sql = @Sql +          ' #Tmp_Peptide_SeqInfo PSI ON RTSM.Seq_ID_Local = PSI.Seq_ID_Local INNER JOIN'
			Set @Sql = @Sql +      ' #Tmp_Peptide_SeqToProteinMap STPM ON PSI.Seq_ID_Local = STPM.Seq_ID_Local'

			If @UseMSGFFilter = 1
				Set @Sql = @Sql +      ' INNER JOIN #Tmp_MSGF_Results MSGF ON TPI.Result_ID = MSGF.Result_ID '

			-- Construct the Where clause
			Set @W = ''
			Set @W = @W +	' STPM.Cleavage_State ' + @CleavageStateComparison + Convert(varchar(6), @CleavageStateThreshold) + ' AND '
			Set @W = @W +	' STPM.Terminus_State ' + @TerminusStateComparison + Convert(varchar(6), @TerminusStateThreshold) + ' AND '
			Set @W = @W +	' TPI.Charge_State ' + @ChargeStateComparison + Convert(varchar(6), @ChargeStateThreshold) + ' AND '
			Set @W = @W +	' PSI.Monoisotopic_Mass ' + @MassComparison + Convert(varchar(11), @MassThreshold)

			If @UseMSGFFilter = 1
				Set @W = @W +      ' AND IsNull(MSGF.SpecProb, 1) ' + @MSGFSpecProbComparison + Convert(varchar(11), @MSGFSpecProbThreshold)

			If @UseMSAlignPValueFilter = 1
				Set @W = @W +      ' AND IsNull(TPI.PValue, 1) ' + @MSAlignPValueComparison + Convert(varchar(11), @MSAlignPValueThreshold)

			If @UseMSAlignFDRFilter = 1
				Set @W = @W +      ' AND IsNull(TPI.FDR, 1) ' + @MSAlignFDRComparison + Convert(varchar(11), @MSAlignFDRThreshold)

			Set @W = @W +    ' ) LookupQ ON LookupQ.Result_ID = TFF.Result_ID'

			-- Append the Where clause to @Sql
			Set @Sql = @Sql + ' WHERE ' + @W


			Set @LogMessage = 'Update #Tmp_Peptide_Filter_Flags for peptides passing the thresholds'
			If @LogLevel >= 3
				Set @LogMessage = @LogMessage + ': ' + @W

			if @LogLevel >= 2
				execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

			-- Execute the Sql to update the matching entries
			Exec (@Sql)
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				set @message = 'Problem marking peptides passing filter in temporary table for job ' + @jobStr
				goto Done
			end

			Set @LogMessage = 'Found ' + Convert(varchar(12), @myRowCount) + ' peptides passing the filter'
			if @LogLevel >= 2
				execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

			-- Lookup the next set of filters
			--
			Set @CriteriaGroupStart = @CriteriaGroupMatch + 1
			Set @CriteriaGroupMatch = 0

			Exec @myError = GetThresholdsForFilterSet @FilterSetID, @CriteriaGroupStart, @CriteriaGroupMatch OUTPUT, @message OUTPUT,
											@SpectrumCountComparison OUTPUT,@SpectrumCountThreshold OUTPUT,
											@ChargeStateComparison OUTPUT,@ChargeStateThreshold OUTPUT,
											@HighNormalizedScoreComparison OUTPUT,@HighNormalizedScoreThreshold OUTPUT,
											@CleavageStateComparison OUTPUT,@CleavageStateThreshold OUTPUT,
											@PeptideLengthComparison OUTPUT,@PeptideLengthThreshold OUTPUT,
											@MassComparison OUTPUT,@MassThreshold OUTPUT,
											@DeltaCnComparison OUTPUT,@DeltaCnThreshold OUTPUT,
											@DeltaCn2Comparison OUTPUT, @DeltaCn2Threshold OUTPUT,
											@DiscriminantScoreComparison OUTPUT, @DiscriminantScoreThreshold OUTPUT,
											@NETDifferenceAbsoluteComparison OUTPUT, @NETDifferenceAbsoluteThreshold OUTPUT,
											@DiscriminantInitialFilterComparison OUTPUT, @DiscriminantInitialFilterThreshold OUTPUT,
											@ProteinCountComparison OUTPUT, @ProteinCountThreshold OUTPUT,
											@TerminusStateComparison OUTPUT, @TerminusStateThreshold OUTPUT,
											@XTandemHyperscoreComparison OUTPUT, @XTandemHyperscoreThreshold OUTPUT,
											@XTandemLogEValueComparison OUTPUT, @XTandemLogEValueThreshold OUTPUT,
											@PeptideProphetComparison OUTPUT, @PeptideProphetThreshold OUTPUT,
											@RankScoreComparison OUTPUT, @RankScoreThreshold OUTPUT,
											@MSGFSpecProbComparison = @MSGFSpecProbComparison OUTPUT, @MSGFSpecProbThreshold = @MSGFSpecProbThreshold OUTPUT,
											@MSAlignPValueComparison = @MSAlignPValueComparison OUTPUT, @MSAlignPValueThreshold = @MSAlignPValueThreshold OUTPUT,
											@MSAlignFDRComparison = @MSAlignFDRComparison OUTPUT, @MSAlignFDRThreshold = @MSAlignFDRThreshold OUTPUT

			If @myError <> 0
			Begin
				Set @Message = 'Error retrieving next entry from GetThresholdsForFilterSet in LoadMSAlignPeptidesBulk'
				Goto Done
			End

		End -- </CriteriaGroupMatch>

	End -- </Filter>

	-----------------------------------------------
	-- Possibly copy the data from #Tmp_Peptide_Import into #Tmp_Peptide_Import_Unfiltered
	-----------------------------------------------
	If @UsingPhysicalTempTables = 1
	Begin
		SELECT *
		INTO #Tmp_Peptide_Import_Unfiltered
		FROM #Tmp_Peptide_Import
		ORDER BY Result_ID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		Set @LogMessage = 'Populated #Tmp_Peptide_Import_Unfiltered with ' + Convert(varchar(12), @myRowCount) + ' rows'
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'
	End


	If @CreateDebugTables = 1
	Begin
		if exists (select * from sys.tables Where Name = 'T_Tmp_Peptide_Import')
		drop table T_Tmp_Peptide_Import

		SELECT TFF.Valid,
		       TPI.*
		INTO T_Tmp_Peptide_Import
		FROM #Tmp_Peptide_Filter_Flags TFF
		     INNER JOIN #Tmp_Peptide_Import TPI
		       ON TFF.Result_ID = TPI.Result_ID

	End


	-----------------------------------------------
	-- Remove peptides falling below threshold
	-----------------------------------------------
	DELETE #Tmp_Peptide_Import
	FROM #Tmp_Peptide_Filter_Flags TFF INNER JOIN
		 #Tmp_Peptide_Import TPI ON TFF.Result_ID = TPI.Result_ID
	WHERE TFF.Valid = 0
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	Set @numSkipped = @myRowCount

	Set @LogMessage = 'Deleted ' + Convert(varchar(12), @myRowCount) + ' entries from #Tmp_Peptide_Import; scores are below thresholds for filter set ' + CONVERT(varchar(11), @FilterSetID)
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'


	-----------------------------------------------
	-- Truncate peptides longer than 850 characters
	-----------------------------------------------
	UPDATE #Tmp_Peptide_Import
	SET Peptide = Substring(Peptide, 1, 847) + '...'
	WHERE Result_ID IN ( SELECT Result_ID
	                     FROM #Tmp_Peptide_Import
	                     WHERE LEN(Peptide) > 850 )

	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	Set @LogMessage = 'Truncated ' + Convert(varchar(12), @myRowCount) + ' entries in #Tmp_Peptide_Import with a peptide sequence over 850 characters'
	if @LogLevel >= 2 And @myRowCount > 0
		execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'


	-----------------------------------------------
	-- Delete any existing results in T_Peptides, T_Score_MSAlign
	-- T_Score_Discriminant, etc. for this analysis job
	-----------------------------------------------

	If Exists (SELECT * FROM T_Peptides WHERE Job = @Job) AND @UpdateExistingData = 0 And @InfoOnly=0
	Begin
		Set @LogMessage = 'Call DeletePeptidesForJobAndResetToNew for Job ' + @jobStr
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

		Exec @myError = DeletePeptidesForJobAndResetToNew @job, @ResetStateToNew=0, @DeleteUnusedSequences=0, @DropAndAddConstraints=0
		--
		if @myError <> 0
		begin
			set @message = 'Problem deleting existing peptide entries for job ' + @jobStr
			Set @myError = 50004
			goto Done
		end
	End

	Set @LogMessage = 'Verifying the validity of data in #Tmp_Peptide_Import'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

	-----------------------------------------------
	-- Make sure all peptides in #Tmp_Peptide_Import have
	-- a Scan Number, Charge, and Peptide defined
	-- Delete any that do not
	-----------------------------------------------
	DELETE FROM #Tmp_Peptide_Import
	WHERE Scan_Number IS NULL OR Charge_State IS NULL OR Peptide IS NULL
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myRowCount > 0
	Begin
		Set @message = 'Newly imported peptides found with Null Scan_Number, Charge_State, or Peptide values for job ' + @jobStr + ' (' + convert(varchar(11), @myRowCount) + ' peptides)'
		execute PostLogEntry 'Error', @message, 'LoadMSAlignPeptidesBulk'
		Set @message = ''
	End

	-----------------------------------------------
	-- If no peptides remain in #Tmp_Peptide_Import
	-- then jump to Done
	-----------------------------------------------
	SELECT @myRowCount = Count(*)
	FROM #Tmp_Peptide_Import
	--
	If @myRowCount = 0
	Begin
		Set @numLoaded = 0
		Goto Done
	End

	-----------------------------------------------
	-- Make sure all peptides in #Tmp_Peptide_SeqToProteinMap have
	--  a reference defined; if any do not, give them
	--  a bogus reference name and post an entry to the log
	-----------------------------------------------
	UPDATE #Tmp_Peptide_SeqToProteinMap
	SET Reference = 'xx_Unknown_Protein_Reference_xx'
	WHERE Reference IS NULL
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myRowCount > 0
	Begin
		Set @message = 'Newly imported peptides found with Null reference values for job ' + @jobStr + ' (' + convert(varchar(11), @myRowCount) + ' peptides)'
		execute PostLogEntry 'Error', @message, 'LoadMSAlignPeptidesBulk'
		Set @message = ''
	End


	Set @LogMessage = 'Data verification complete'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

	-----------------------------------------------
	-- Generate a temporary table listing the minimum Result_ID value
	--  for each unique combination of Scan_Number, Charge_State, MH, Peptide
	-- For MSAlign data there should not be any duplicate rows in #Tmp_Peptide_Import,
	--  but we'll check to be sure and to stay symmetric with Sequest Synopsis files
	-----------------------------------------------

	CREATE TABLE #Tmp_Unique_Records (
		Peptide_ID_Base int IDENTITY(1,1) NOT NULL,
		Result_ID int NOT NULL ,
		Peptide_ID_New int NULL ,
		Scan_Number int NOT NULL ,
		Number_Of_Scans int NOT NULL ,
		Charge_State smallint NOT NULL ,
		MH float NOT NULL ,
		Peptide varchar (850) NOT NULL
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #Tmp_Unique_Records for job ' + @jobStr
		goto Done
	end

	CREATE CLUSTERED INDEX #IX_Tmp_Unique_Records_Result_ID ON #Tmp_Unique_Records (Result_ID)
	CREATE INDEX #IX_Tmp_Unique_Records_MH ON #Tmp_Unique_Records (MH)
	CREATE INDEX #IX_Tmp_Unique_Records_Scan_Number ON #Tmp_Unique_Records (Scan_Number)


	-----------------------------------------------
	-- Populate #Tmp_Unique_Records
	-----------------------------------------------
	--
	INSERT INTO #Tmp_Unique_Records (Result_ID, Scan_Number, Number_Of_Scans, Charge_State, MH, Peptide)
	SELECT MIN(TPI.Result_ID), TPI.Scan_Number, 1 AS Number_Of_Scans, TPI.Charge_State, TPI.MH, TPI.Peptide
	FROM #Tmp_Peptide_Import TPI INNER JOIN
		 #Tmp_Peptide_ResultToSeqMap RTSM ON TPI.Result_ID = RTSM.Result_ID
	GROUP BY TPI.Scan_Number, TPI.Charge_State, TPI.MH, TPI.Peptide
	ORDER BY MIN(TPI.PValue), TPI.Scan_Number, TPI.Peptide
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem populating temporary table #Tmp_Unique_Records ' + @jobStr
		goto Done
	end
	--
	if @myRowCount = 0
	Begin
		set @myError = 50005
		set @message = '#Tmp_Unique_Records table populated with no records for job ' + @jobStr
		goto Done
	End

	Set @LogMessage = 'Populated #Tmp_Unique_Records with ' + Convert(varchar(12), @myRowCount) + ' rows'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'


	If @CreateDebugTables = 1
	Begin
		if exists (select * from sys.tables Where Name = 'T_Tmp_Unique_Records')
		drop table T_Tmp_Unique_Records

		if exists (select * from sys.tables Where Name = 'T_Tmp_Peptide_ResultToSeqMap')
		drop table T_Tmp_Peptide_ResultToSeqMap

		if exists (select * from sys.tables Where Name = 'T_Tmp_Peptide_SeqInfo')
		drop table T_Tmp_Peptide_SeqInfo

		SELECT *
		INTO T_Tmp_Peptide_ResultToSeqMap
		FROM #Tmp_Peptide_ResultToSeqMap

		SELECT *
		INTO T_Tmp_Peptide_SeqInfo
		FROM #Tmp_Peptide_SeqInfo
	End

	If @infoOnly <> 0
	Begin
		SELECT TOP 1000 '#Tmp_Unique_Records' As Source, * FROM #Tmp_Unique_Records
		Goto Done
	End

	---------------------------------------------------
	-- Possibly create the table for caching log entries
	-- Procedure PostLogEntryAddToCache requires this table to exist
	-- We cache log entries made between the "Begin Transaction" and "Commit Transaction" statements
	--  to avoid locking T_Log_Entries
	---------------------------------------------------
	--
	if @LogLevel >= 2
	Begin
		CREATE TABLE #Tmp_Cached_Log_Entries (
			[Entry_ID] int IDENTITY(1,1) NOT NULL,
			[posted_by] varchar(128) NULL,
			[posting_time] datetime NOT NULL DEFAULT (getdate()),
			[type] varchar(128) NULL,
			[message] varchar(4096) NULL,
			[Entered_By] varchar(128) NULL DEFAULT (suser_sname()),
		)
	End


	---------------------------------------------------
	--  Start a transaction
	---------------------------------------------------

	declare @numAddedPeptides int
	declare @numAddedMSAlignScores int
	declare @numAddedDiscScores int

	Set @LogMessage = 'Begin Transaction'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

	declare @transName varchar(32)
	set @transName = 'LoadMSAlignPeptidesBulk'
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start peptide load'

	Begin Try
		begin transaction @transName

		If @UpdateExistingData = 0
		Begin -- <a1>

			-----------------------------------------------
			-- Get base value for peptide ID calculation
			-- Note that @MaxPeptideID will get added to #Tmp_Unique_Records.Peptide_ID_Base,
			--  which will always start at 1
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Lookup Max Peptide_ID'

			declare @MaxPeptideID int
			set @MaxPeptideID = 0
			--
			SELECT  @MaxPeptideID = IsNull(MAX(Peptide_ID), 1000)
			FROM T_Peptides
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0 or @MaxPeptideID = 0
			begin
				rollback transaction @transName
				set @message = 'Problem getting base for peptide ID for job ' + @jobStr
				If @myError = 0
					Set @myError = 50006
				goto Done
			end

			-----------------------------------------------
			-- Populate the Peptide_ID_New column in #Tmp_Unique_Records
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Populate the Peptide_ID_New'

			UPDATE #Tmp_Unique_Records
			SET Peptide_ID_New = Peptide_ID_Base + @MaxPeptideID
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				rollback transaction @transName
				set @message = 'Problem updating Peptide_ID_New column in temporary table for job ' + @jobStr
				goto Done
			end

			Set @LogMessage = 'Updated ' + Convert(varchar(12), @myRowCount) + ' rows in #Tmp_Unique_Records'
			if @LogLevel >= 2
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'


			If @CreateDebugTables = 1
			Begin
				SELECT *
				INTO T_Tmp_Unique_Records
				FROM #Tmp_Unique_Records
			End

			-----------------------------------------------
			-- Add new proteins to T_Proteins
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Add new proteins to T_Proteins'

			INSERT INTO T_Proteins (Reference)
			SELECT LookupQ.Reference
			FROM (	SELECT STPM.Reference
					FROM #Tmp_Peptide_Import TPI INNER JOIN
						 #Tmp_Peptide_ResultToSeqMap RTSM ON TPI.Result_ID = RTSM.Result_ID INNER JOIN
						 #Tmp_Peptide_SeqInfo PSI ON RTSM.Seq_ID_Local = PSI.Seq_ID_Local INNER JOIN
						 #Tmp_Peptide_SeqToProteinMap STPM ON PSI.Seq_ID_Local = STPM.Seq_ID_Local
					GROUP BY STPM.Reference
				 ) LookupQ LEFT OUTER JOIN
				 T_Proteins ON LookupQ.Reference = T_Proteins.Reference
			WHERE T_Proteins.Ref_ID IS NULL
			ORDER BY LookupQ.Reference
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				rollback transaction @transName
				set @message = 'Error inserting into T_Proteins for job ' + @jobStr
				goto Done
			end

			Set @LogMessage = 'Populated T_Proteins with ' + Convert(varchar(12), @myRowCount) + ' rows'
			if @LogLevel >= 2
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

			-----------------------------------------------
			-- Copy selected contents of #Tmp_Peptide_Import
			-- into T_Peptides
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Populate T_Peptides using #Tmp_Peptide_Import'

			SET IDENTITY_INSERT T_Peptides ON
			--
			INSERT INTO T_Peptides
			(
				Peptide_ID,
				Job,
				Scan_Number,
				Number_Of_Scans,
				Charge_State,
				MH,
				Multiple_ORF,
				Peptide,
				RankHit,
				DelM_PPM
			)
			SELECT
				UR.Peptide_ID_New,
				@Job,					-- Job
				TPI.Scan_Number,
				1 AS Number_of_Scans,
				TPI.Charge_State,
				TPI.MH,
				0,						-- Multiple_Protein_Count; this set to 0 for now, but we will update it below using T_Peptides and T_Peptide_to_Protein_Map
				TPI.Peptide,
				TPI.Rank_PValue AS RankHit,
				TPI.DelM_PPM
			FROM #Tmp_Peptide_Import TPI INNER JOIN
				 #Tmp_Unique_Records UR ON TPI.Result_ID = UR.Result_ID
			ORDER BY UR.Peptide_ID_New
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				rollback transaction @transName
				set @message = 'Error inserting into T_Peptides for job ' + @jobStr
				goto Done
			end
			Set @numAddedPeptides = @myRowCount

			Set @LogMessage = 'Populated T_Peptides with ' + Convert(varchar(12), @myRowCount) + ' rows'
			if @LogLevel >= 2
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

			SET IDENTITY_INSERT T_Peptides OFF


			-----------------------------------------------
			-- Count the number of truncated peptides that were stored in T_Peptides
			-----------------------------------------------
			--
			Set @myRowCount = 0

			SELECT @myRowCount = COUNT(*)
			FROM #Tmp_Peptide_Import TPI INNER JOIN
				 #Tmp_Unique_Records UR ON TPI.Result_ID = UR.Result_ID
			WHERE TPI.Peptide LIKE '%...'

			Set @LogMessage = 'Stored ' + Convert(varchar(12), @myRowCount) + ' truncated peptides in T_Peptides for job ' + @jobStr + '; maximum allowed peptide length is 850 characters'
			if @LogLevel >= 1 And @myRowCount > 0
				execute PostLogEntry 'Warning', @LogMessage, 'LoadMSAlignPeptidesBulk'

			-----------------------------------------------
			-- Copy selected contents of #Tmp_Peptide_Import
			-- into T_Score_Discriminant
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Populate T_Score_Discriminant using #Tmp_Peptide_Import'

			INSERT INTO T_Score_Discriminant
				(Peptide_ID, MScore, PassFilt, DiscriminantScore, DiscriminantScoreNorm, Peptide_Prophet_FScore, Peptide_Prophet_Probability, MSGF_SpecProb)
			SELECT
				UR.Peptide_ID_New,
				10.75,				-- MScore is set to 10.75 for all MSAlign results
				1,					-- PassFilt is set to 1 for all MSAlign results
				1,					-- DiscriminantScore is set to 1 for all MSAlign results
				0.5,				-- DiscriminantScoreNorm is set to 0.5 for all MSAlign results
				NULL,				-- FScore is set to Null for all MSAlign results
				1 - TPI.PValue,		-- 1 minus MSAlign PValue is Probability; storing this probability value in the Peptide_Prophet_Probability column (Note: the STAC algorithm used by VIPER weights peptides by Peptide_Prophet_Probability)
				TPI.PValue			-- Store PValue from MSAlign in T_Score_Discriminant.MSGF_SpecProb
			FROM #Tmp_Peptide_Import TPI INNER JOIN
				 #Tmp_Unique_Records UR ON TPI.Result_ID = UR.Result_ID
			ORDER BY UR.Peptide_ID_New
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				rollback transaction @transName
				set @message = 'Error inserting into T_Score_Discriminant for job ' + @jobStr
				goto Done
			end
			Set @numAddedDiscScores = @myRowCount

			Set @LogMessage = 'Populated T_Score_Discriminant with ' + Convert(varchar(12), @myRowCount) + ' rows'
			if @LogLevel >= 2
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'


			-----------------------------------------------
			-- Copy selected contents of #Tmp_Peptide_Import into T_Score_MSAlign
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Populate T_Score_MSAlign using #Tmp_Peptide_Import'

			INSERT INTO T_Score_MSAlign
				(Peptide_ID, Prsm_ID, PrecursorMZ, DelM, Unexpected_Mod_Count,
				 Peak_Count, Matched_Peak_Count, Matched_Fragment_Ion_Count, PValue, EValue, FDR, Normalized_Score)
			SELECT
				UR.Peptide_ID_New,
				TPI.Prsm_ID,
				TPI.PrecursorMZ,
				TPI.DelM,
				TPI.Unexpected_Mod_Count,
				TPI.Peak_Count,
				TPI.Matched_Peak_Count,
				TPI.Matched_Fragment_Ion_Count,
				TPI.PValue,
				TPI.EValue,
				TPI.FDR,
				dbo.udfMSAlignScoreToNormalizedScore(TPI.PValue, TPI.Charge_State)		-- Compute the Normalized Score using PValue and Charge_State
			FROM #Tmp_Peptide_Import TPI INNER JOIN
				 #Tmp_Unique_Records UR ON TPI.Result_ID = UR.Result_ID
			ORDER BY UR.Peptide_ID_New
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				rollback transaction @transName
				set @message = 'Error inserting into T_Score_MSAlign for job ' + @jobStr
				goto Done
			end
			Set @numAddedMSAlignScores = @myRowCount

			Set @LogMessage = 'Populated T_Score_MSAlign with ' + Convert(varchar(12), @myRowCount) + ' rows'
			if @LogLevel >= 2
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'


			-----------------------------------------------
			-- Copy selected contents of #Tmp_Peptide_Import and
			--  #Tmp_Peptide_SeqToProteinMap into T_Peptide_to_Protein_Map table;
			-- We shouldn't have to use the Group By when inserting, but if the synopsis file
			--  has multiple entries for the same combination of Scan_Number,
			--  Charge_State, MH, and Peptide pointing to the same Reference, then this
			--  will cause a primary key constraint error.
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Populate T_Peptide_to_Protein_Map'

			INSERT INTO T_Peptide_to_Protein_Map (Peptide_ID, Ref_ID, Cleavage_State, Terminus_State)
			SELECT	UR.Peptide_ID_New, P.Ref_ID,
					MAX(IsNull(STPM.Cleavage_State, 0)),
					MAX(IsNull(STPM.Terminus_State, 0))
			FROM #Tmp_Unique_Records UR INNER JOIN
				 #Tmp_Peptide_Import TPI ON
					UR.Scan_Number = TPI.Scan_Number AND
					UR.Charge_State = TPI.Charge_State AND
					UR.MH = TPI.MH AND
					UR.Peptide = TPI.Peptide INNER JOIN
				 #Tmp_Peptide_ResultToSeqMap RTSM ON TPI.Result_ID = RTSM.Result_ID INNER JOIN
				 #Tmp_Peptide_SeqInfo PSI ON RTSM.Seq_ID_Local = PSI.Seq_ID_Local INNER JOIN
				 #Tmp_Peptide_SeqToProteinMap STPM ON PSI.Seq_ID_Local = STPM.Seq_ID_Local INNER JOIN
				 T_Proteins P ON STPM.Reference = P.Reference
			GROUP BY UR.Peptide_ID_New, P.Ref_ID
			ORDER BY UR.Peptide_ID_New
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				rollback transaction @transName
				set @message = 'Error inserting into T_Peptide_to_Protein_Map for job ' + @jobStr
				goto Done
			end

			Set @LogMessage = 'Populated T_Peptide_to_Protein_Map with ' + Convert(varchar(12), @myRowCount) + ' rows'
			Set @LogMessage = @LogMessage + ' (used the SeqInfo file data)'

			if @LogLevel >= 2
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'


			-----------------------------------------------
			-- Verify that all inserts have same number of rows
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Verify counts'

			Set @numAddedPeptides = IsNull(@numAddedPeptides, 0)
			Set @numAddedMSAlignScores = IsNull(@numAddedMSAlignScores, 0)
			Set @numAddedDiscScores = IsNull(@numAddedDiscScores, 0)

			if @numAddedPeptides <> @numAddedMSAlignScores
			begin
				rollback transaction @transName
				set @message = 'Error in rowcounts for @numAddedPeptides vs @numAddedMSAlignScores for job ' + @jobStr + '; ' + Convert(varchar(12), @numAddedPeptides) + ' <> ' + Convert(varchar(12), @numAddedMSAlignScores)
				Set @myError = 50007
				Set @numLoaded = 0
				goto Done
			end

			if @numAddedPeptides <> @numAddedDiscScores
			begin
				rollback transaction @transName
				set @message = 'Error in rowcounts for @numAddedPeptides vs @numAddedDiscScores for job ' + @jobStr + '; ' + Convert(varchar(12), @numAddedPeptides) + ' <> ' + Convert(varchar(12), @numAddedDiscScores)
				Set @myError = 50008
				Set @numLoaded = 0
				goto Done
			end

			Set @numLoaded = @numAddedPeptides


		End -- </a1>
		Else
		Begin -- <a2>

			-----------------------------------------------
			-- Updating existing records
			-- Populate the Peptide_ID_New column in #Tmp_Unique_Records using T_Peptides
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Update Peptide_ID_New in #Tmp_Unique_Records'
			--
			UPDATE #Tmp_Unique_Records
			SET Peptide_ID_New = P.Peptide_ID
			FROM #Tmp_Peptide_Import TPI
			     INNER JOIN #Tmp_Unique_Records UR
			       ON TPI.Result_ID = UR.Result_ID
			     INNER JOIN T_Peptides P
			       ON P.Job = @Job AND
			          P.Scan_Number = TPI.Scan_Number AND
			          P.Charge_State = TPI.Charge_State AND
			          P.Peptide = TPI.Peptide
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			If @CreateDebugTables = 1
			Begin
				SELECT *
				INTO T_Tmp_Unique_Records
				FROM #Tmp_Unique_Records
			End

			-- Examine #Tmp_Unique_Records to determine the percentage of data that didn't match to T_Peptides
			-- If the percentage is over 5% then we likely have a problem
			Declare @UnmatchedRowCount int = 0
			Set @numLoaded = 0

			SELECT @numLoaded = COUNT(*),
			       @UnmatchedRowCount = SUM(CASE WHEN Peptide_ID_New IS NULL THEN 1 ELSE 0 END)
			FROM #Tmp_Unique_Records


			If @numLoaded > 0
			Begin
				Declare @PercentageUnmatched decimal(9,2)
				Set @PercentageUnmatched = @UnmatchedRowCount / convert(real, @numLoaded) * 100.0

				if @PercentageUnmatched > 0
				Begin
					Set @LogMessage = Convert(varchar(12), @PercentageUnmatched) + '% of the loaded data for job ' + @jobStr + ' did not match existing data in T_Peptides (' + Convert(varchar(12), @UnmatchedRowCount) + ' / ' + Convert(varchar(12), @numLoaded) + ')'

					If @PercentageUnmatched > 5
					Begin
						Set @LogMessage = @LogMessage + '; this likely indicates a problem'
						exec PostLogEntry 'Error', @LogMessage, 'LoadMSAlignPeptidesBulk'
					End
					Else
					Begin
						exec PostLogEntry 'Warning', @LogMessage, 'LoadMSAlignPeptidesBulk'
					End
				End
			End

			-----------------------------------------------
			-- Update T_Peptides
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Update T_Peptides using #Tmp_Peptide_Import'

			UPDATE T_Peptides
			SET MH = TPI.MH,
			    RankHit = TPI.Rank_PValue,
			    DelM_PPM = TPI.DelM_PPM
			FROM #Tmp_Peptide_Import TPI
			     INNER JOIN #Tmp_Unique_Records UR
			       ON TPI.Result_ID = UR.Result_ID
			     INNER JOIN T_Peptides Pep
			       ON Pep.Peptide_ID = UR.Peptide_ID_New
			WHERE IsNull(Pep.MH, -1) <> TPI.MH OR
			      IsNull(Pep.RankHit, 0) <> TPI.Rank_PValue OR
			      IsNull(Pep.DelM_PPM, -9999) <> TPI.DelM_PPM
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				rollback transaction @transName
				set @message = 'Error updating T_Peptides for job ' + @jobStr
				goto Done
			end
			Set @numAddedPeptides = @myRowCount

			Set @LogMessage = 'Updated ' + Convert(varchar(12), @myRowCount) + ' rows in T_Peptides'
			if @LogLevel >= 2
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'


			-----------------------------------------------
			-- Update T_Score_Discriminant
			-- Note that all MSAlign results have MScore = 10.75, PassFilt = 1, DiscriminantScore = 1, DiscriminantScoreNorm = 0.5, and FScore = Null
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Update T_Score_Discriminant using #Tmp_Peptide_Import'

			UPDATE T_Score_Discriminant
			SET Peptide_Prophet_Probability = 1 - TPI.PValue,		-- 1 minus MSAlign PValue is Probability
				MSGF_SpecProb = TPI.PValue							-- Store PValue from MSAlign in T_Score_Discriminant.MSGF_SpecProb
			FROM #Tmp_Peptide_Import TPI
			     INNER JOIN #Tmp_Unique_Records UR
			       ON TPI.Result_ID = UR.Result_ID
			    INNER JOIN T_Score_Discriminant SD
			       ON SD.Peptide_ID = UR.Peptide_ID_New
			WHERE IsNull(SD.Peptide_Prophet_Probability, -1) <> 1 - TPI.PValue
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			if @myError <> 0
			begin
				rollback transaction @transName
				set @message = 'Error updating T_Score_Discriminant for job ' + @jobStr
				goto Done
			end
			Set @numAddedDiscScores = @myRowCount

			Set @LogMessage = 'Updated ' + Convert(varchar(12), @myRowCount) + ' rows in T_Score_Discriminant'
			if @LogLevel >= 2
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'


			-----------------------------------------------
			-- Update T_Score_MSAlign
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Update T_Score_MSAlign using #Tmp_Peptide_Import'

			UPDATE T_Score_MSAlign
			SET Prsm_ID = TPI.Prsm_ID,
			    PrecursorMZ = TPI.PrecursorMZ,
			    DelM = TPI.DelM,
			    Unexpected_Mod_Count = TPI.Unexpected_Mod_Count,
			    Peak_Count = TPI.Peak_Count,
			    Matched_Peak_Count = TPI.Matched_Peak_Count,
			    Matched_Fragment_Ion_Count = TPI.Matched_Fragment_Ion_Count,
			    PValue = TPI.PValue,
			    EValue = TPI.EValue,
			    FDR = TPI.FDR,
			    Normalized_Score = dbo.udfMSAlignScoreToNormalizedScore(TPI.PValue, TPI.Charge_State)
			FROM #Tmp_Peptide_Import TPI
			     INNER JOIN #Tmp_Unique_Records UR
			       ON TPI.Result_ID = UR.Result_ID
			     INNER JOIN T_Peptides Pep
			       ON Pep.Peptide_ID = UR.Peptide_ID_New
			     INNER JOIN T_Score_MSAlign MSA
			       ON Pep.Peptide_ID = MSA.Peptide_ID
			WHERE
			      IsNull(MSA.Prsm_ID, -9999) <> TPI.Prsm_ID OR
			      IsNull(MSA.PrecursorMZ, -9999) <> TPI.PrecursorMZ OR
			      IsNull(MSA.DelM, -9999) <> TPI.DelM OR
			      IsNull(MSA.Unexpected_Mod_Count, -9999) <> TPI.Unexpected_Mod_Count OR
			      IsNull(MSA.Peak_Count, -9999) <> TPI.Peak_Count OR
			      IsNull(MSA.Matched_Peak_Count, -9999) <> TPI.Matched_Peak_Count OR
			   IsNull(MSA.Matched_Fragment_Ion_Count, -9999) <> TPI.Matched_Fragment_Ion_Count OR
			      IsNull(MSA.PValue, -9999) <> TPI.PValue OR
			      IsNull(MSA.EValue, -9999) <> TPI.EValue OR
			      IsNull(MSA.FDR, -9999) <> TPI.FDR

			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				rollback transaction @transName
				set @message = 'Error updating T_Score_MSAlign for job ' + @jobStr
				goto Done
			end
			Set @numAddedMSAlignScores = @myRowCount

			Set @LogMessage = 'Updated ' + Convert(varchar(12), @myRowCount) + ' rows in T_Score_MSAlign'
			if @LogLevel >= 2
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

			-----------------------------------------------
			-- Change Normalized_Score to -Normalized_Score for peptides that are in T_Score_MSAlign yet are not in #Tmp_Peptide_Import
			-- This will commonly be the case if the data was loosely filtered when it was initially loaded but was
			-- filtered out of #Tmp_Peptide_Import on this load
			-----------------------------------------------
			--
			UPDATE T_Score_MSAlign
			SET PValue = 10,
			    Normalized_Score = -ABS(Normalized_Score),
			    FDR = Case When FDR Is Null Then Null Else 10 End
			FROM T_Peptides Pep
			     INNER JOIN T_Score_MSAlign MSA
			      ON Pep.Peptide_ID = MSA.Peptide_ID
			     LEFT OUTER JOIN #Tmp_Unique_Records UR
			       ON Pep.Peptide_ID = UR.Peptide_ID_New
			WHERE Pep.Job = @Job AND
			      (MSG.PValue < 10 OR MSG.Normalized_Score > 0 OR FDR < 10) AND
			      UR.Peptide_ID_New IS NULL
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			If @myRowCount > 0
			Begin
				Set @LogMessage = 'Changed Normalized_Score to a negative value for ' + Convert(varchar(12), @myRowCount) + ' entries for job ' + @jobStr + ' since the peptides no longer pass filters'
				execute PostLogEntry 'Warning', @LogMessage, 'LoadMSAlignPeptidesBulk'
			End

			-----------------------------------------------
			-- Note: we do not update T_Proteins or T_Peptide_to_Protein_Map
			-----------------------------------------------

			SELECT @numLoaded = COUNT(*)
			FROM #Tmp_Unique_Records

		End -- </a2>


		-----------------------------------------------
		-- Commit changes to T_Peptides, T_Score_MSAlign, etc. if we made it this far
		-----------------------------------------------
		--
		commit transaction @transName

		Set @LogMessage = 'Transaction committed'
		if @LogLevel >= 2
		Begin
			execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'
			execute PostLogEntryFlushCache
		End


	End Try
	Begin Catch
		if @@TranCount > 0
			rollback transaction

		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'LoadMSAlignPeptidesBulk')
		Set @CurrentLocation = @CurrentLocation + '; job ' + @jobStr

		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output

		If @myError = 0
			Set @myError = 60012
	End Catch

	-----------------------------------------------
	-- Now that the transaction is commited, we will
	-- store the MSGF values in T_Score_Discriminant
	-- We do this outside of the transaction since this can be a slow process
	-----------------------------------------------

	-----------------------------------------------
	-- Populate #Tmp_Peptide_Import_MatchedEntries with a list of equivalent rows in #Tmp_Peptide_Import
	-- This table is used by StoreMSGFValues
	-----------------------------------------------
	--
	INSERT INTO #Tmp_Peptide_Import_MatchedEntries( Result_ID1,
	                                                Result_ID2 )
	SELECT TPI.Result_ID AS ResultID1,
	       TPI2.Result_ID AS ResultID2
	FROM #Tmp_Unique_Records UR
	     INNER JOIN #Tmp_Peptide_Import TPI2
	       ON UR.Result_ID = TPI2.Result_ID
	  INNER JOIN #Tmp_Peptide_Import TPI
	       ON TPI2.Scan_Number = TPI.Scan_Number AND
	          TPI2.Charge_State = TPI.Charge_State AND
	          TPI2.PValue = TPI.PValue AND
	          TPI2.Peptide = TPI.Peptide AND
	          TPI2.Result_ID <> TPI.Result_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


	Set @LogMessage = 'Populated #Tmp_Peptide_Import_MatchedEntries with ' + Convert(varchar(12), @myRowCount) + ' rows'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'


	-----------------------------------------------
	-- Populate the MSGF_SpecProb column in T_Score_Discriminant
	-----------------------------------------------
	--
	If @MSGFCountLoaded > 0
	Begin
		Set @MSGFFileFound = 1

		Exec StoreMSGFValues @job, @numAddedDiscScores,
						     @LogLevel, @LogMessage,
							 @UsingPhysicalTempTables,
							 @UpdateExistingData,
							 @infoOnly=0, @message=@message output

	End
	Else
	Begin
		Set @MSGFCountLoaded = 0
	End

	If @UpdateExistingData = 0
	Begin
		-----------------------------------------------
		-- Update Multiple_ORF column in T_Peptides
		-----------------------------------------------
		UPDATE T_Peptides
		SET Multiple_ORF = ProteinCount - 1
		FROM T_Peptides
		     INNER JOIN ( SELECT Pep.Peptide_ID,
		                         COUNT(DISTINCT PPM.Ref_ID) AS ProteinCount
		                  FROM T_Peptides Pep
		                       INNER JOIN T_Peptide_to_Protein_Map PPM
		                         ON Pep.Peptide_ID = PPM.Peptide_ID
		        WHERE (Pep.Job = @job)
		                  GROUP BY Pep.Job, Pep.Peptide_ID
                 ) CountQ
		       ON T_Peptides.Peptide_ID = CountQ.Peptide_ID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		-----------------------------------------------
		-- See if any entries in T_Peptides now have Multiple_ORF < 0
		-----------------------------------------------
		Set @MatchCount = 0

		SELECT @MatchCount = COUNT(*)
		FROM T_Peptides
		WHERE Job = @job AND Multiple_ORF < 0
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		If @MatchCount > 0
		Begin
			Set @message = 'Newly imported peptides found with no mapped proteins in T_Peptide_to_Protein_Map for job ' + @jobStr + ' (' + convert(varchar(11), @MatchCount) + ' peptides)'
			execute PostLogEntry 'Error', @message, 'LoadMSAlignPeptidesBulk'
		End


		-----------------------------------------------
		-- Update column Cleavage_State_Max in T_Peptides
		-----------------------------------------------
		exec @myError = UpdatePeptideCleavageStateMax @JobList = @job, @message = @message output

		if @myError <> 0
		Begin
			If Len(IsNull(@message, '')) = 0
				Set @message = 'Error calling UpdatePeptideCleavageStateMax for job ' + @jobStr
			Goto Done
		End

		Set @LogMessage = 'Updated Cleavage_State_Max in T_Peptides'
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

	End

	-----------------------------------------------
	-- Update column State_ID in T_Peptides
	-----------------------------------------------
	exec @myError = UpdatePeptideStateID @job, @message output

	if @myError <> 0
	Begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling UpdatePeptideStateID for job ' + @jobStr
		Goto Done
	End

	Set @LogMessage = 'Updated State_ID in T_Peptides'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'


	-----------------------------------------------
	-- If @ResultToSeqMapCountLoaded > 0, then call LoadSeqInfoAndModsPart2
	--  to populate the Candidate Sequence tables (this should always be true for MSAlign)
	-- Note that LoadSeqInfoAndModsPart2 uses tables:
	--  #Tmp_Peptide_Import
	--  #Tmp_Unique_Records
	--  #Tmp_Peptide_ResultToSeqMap
	--  #Tmp_Peptide_SeqInfo
	--  #Tmp_Peptide_ModDetails
	--  #Tmp_Peptide_ModSummary
	-----------------------------------------------
	--
	If @ResultToSeqMapCountLoaded > 0 And @UpdateExistingData = 0
	Begin
		exec @myError = LoadSeqInfoAndModsPart2 @job, @message output

		if @myError <> 0
		Begin
			If Len(IsNull(@message, '')) = 0
				Set @message = 'Error calling LoadSeqInfoAndModsPart2 for job ' + @jobStr
			Goto Done
		End

		Set @LogMessage = 'Completed call to LoadSeqInfoAndModsPart2'
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadMSAlignPeptidesBulk'

	End

Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[LoadMSAlignPeptidesBulk] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[LoadMSAlignPeptidesBulk] TO [MTS_DB_Lite] AS [dbo]
GO
