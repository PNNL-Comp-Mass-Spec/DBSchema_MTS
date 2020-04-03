/****** Object:  StoredProcedure [dbo].[LoadXTandemPeptidesBulk] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure LoadXTandemPeptidesBulk
/****************************************************
**
**	Desc:
**		Load peptides from synopsis file into peptides table
**		for given analysis job using bulk loading techniques
**
**		Note: This routine will not load peptides with a Hyperscore value
**			  below minimum thresholds (as defined by @FilterSetID)
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	12/16/2005
**			01/15/2006 mem - Added parameters @PeptideSeqInfoFilePath and @PeptideSeqModDetailsFilePath and added call to LoadSeqInfoAndModsPart1
**			01/25/2006 mem - Now considering @CleavageState and @TerminusState when filtering
**			02/15/2006 mem - Added parameters @PeptideResultToSeqMapFilePath and @PeptideSeqToProteinMapFilePath
**			06/04/2006 mem - Added parameter @LineCountToSkip, which is used during Bulk Insert
**			07/18/2006 mem - Now considering charge state thresholds when filtering data
**			08/03/2006 mem - Added parameter @PeptideProphetResultsFilePath
**			08/10/2006 mem - Added parameters @SeqCandidateFilesFound and @PepProphetFileFound
**						   - Added warning if peptide prophet results file does not contain the same number of rows as the synopsis file
**			08/14/2006 mem - Updated peptide prophet results processing to consider charge state when counting the number of null entries
**			10/10/2006 mem - Now checking for protein names longer than 34 characters
**			11/27/2006 mem - Now calling UpdatePeptideStateID
**			03/06/2007 mem - Now considering @PeptideProphet and @RankScore when filtering
**			08/27/2008 mem - Added additional logging when LogLevel >= 2
**			09/24/2008 mem - Now allowing for @FilterSetID to be 0 (which will disable any filtering)
**			09/22/2009 mem - Now calling UpdatePeptideCleavageStateMax
**			07/23/2010 mem - Added support for MSGF results
**						   - Added 'xxx.%' as a potential prefix for reversed proteins
**			02/01/2011 mem - Added support for MSGF filtering
**			02/25/2011 mem - Expanded SpecProbNote to varchar(512) in #Tmp_MSGF_Results
**			03/08/2011 mem - Now using udfLogEValueToPeptideProphetEstimate to populate Peptide_Prophet_Probability when @PeptideProphetResultsFilePath is empty (and it typically will be empty)
**			08/19/2011 mem - Added parameters @SynFileColCount and @SynFileHeader
						   - Now populating columns RankHit and DelM_PPM
**			08/22/2011 mem - Switched DelM_PPM from float to real
**			09/14/2011 mem - Now using MSGF filter even if @MSGFCountLoaded = 0
**			12/24/2011 mem - Added support for updating existing data as an alternative to loading new data
**						   - Added switch @UpdateExistingData
**			01/03/2012 mem - Now leaving Normalized_Score unchanged when updating existing data if Hyperscore is negative
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			12/04/2012 mem - Now populating #Tmp_Peptide_ModSummary
**			12/06/2012 mem - Expanded @message to varchar(1024)
**          04/09/2020 mem - Expand Mass_Correction_Tag to varchar(32)
**
*****************************************************/
(
	@PeptideSynFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_xt.txt',
	@PeptideResultToSeqMapFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_ResultToSeqMap.txt',
	@PeptideSeqInfoFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_SeqInfo.txt',
	@PeptideSeqModDetailsFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_ModDetails.txt',
	@PeptideSeqToProteinMapFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_SeqToProteinMap.txt',
	@PeptideProphetResultsFilePath varchar(512) =  'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_xt_PepProphet.txt',
	@MSGFResultsFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_xt_MSGF.txt',
	@Job int,
	@FilterSetID int,
	@LineCountToSkip int=1,
	@SynFileColCount int,
	@SynFileHeader varchar(2048),
	@UpdateExistingData tinyint,
	@numLoaded int=0 output,
	@numSkipped int=0 output,
	@SeqCandidateFilesFound tinyint=0 output,
	@PepProphetFileFound tinyint=0 output,
	@MSGFFileFound tinyint=0 output,
	@message varchar(1024)='' output
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
	set @PepProphetFileFound = 0
	set @MSGFFileFound = 0
	set @message = ''

	Set @SynFileColCount = IsNull(@SynFileColCount, 0)
	Set @SynFileHeader = IsNull(@SynFileHeader, '')

	declare @jobStr varchar(12)
	set @jobStr = convert(varchar(12), @Job)

	declare @Sql varchar(2048)
	declare @W varchar(1024)

	declare @UnfilteredCountLoaded int
	set @UnfilteredCountLoaded = 0

	declare @RowCountTotal int
	declare @RowCountNull int
	declare @RowCountNullCharge5OrLess int
	declare @MessageType varchar(32)

	declare @LongProteinNameCount int
	set @LongProteinNameCount = 0

	declare @UsePeptideProphetFilter tinyint
	declare @UseMSGFFilter tinyint

	declare @LogLevel int
	declare @LogMessage varchar(512)

	-----------------------------------------------
	-- Lookup the logging level from T_Process_Step_Control
	-----------------------------------------------

	Set @LogLevel = 1
	SELECT @LogLevel = enabled
	FROM T_Process_Step_Control
	WHERE (Processing_Step_Name = 'LogLevel')
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	Set @LogMessage = 'Loading XTandem results for Job ' + @jobStr + '; create temporary tables'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

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
	-- of XTandem synopsis file (_xt.txt)
	-----------------------------------------------
	--
	Declare @SynFileVersion varchar(64)
	Set @SynFileVersion = ''

	If @SynFileColCount IN (0, 16) OR @SynFileHeader = ''
	Begin
		Set @SynFileVersion = '2005'
	End

	If @SynFileVersion = ''
	Begin
		If @SynFileColCount = 17 And @SynFileHeader Like '%DelM[_]PPM%'
			Set @SynFileVersion = '2011'
	End

	If @SynFileVersion = ''
	Begin
		-- Unrecognized version
		if @myError = 52005
		begin
			set @message = 'Unrecognized Synopsis file format for Job ' + @jobStr
			Set @message = @message + '; synopsis file contains ' + convert(varchar(12), @SynFileColCount) + ' columns (Expecting 16 or 17 columns)'
			goto Done
		end
	End

	--	Result_ID					Unique row id
	--	Group_ID					Group_ID
	--	Scan						Scan Number
	--	Charge						Charge State
	--	Peptide_MH					Monoisotopic mass (M+H)+ of the peptide as computed by XTandem
	--	Peptide_Hyperscore
	--	Peptide_Expectation_Value_Log(e)	Base-10 log of the peptide E-value
	--  Multiple_Protein_Count				0 if the peptide only maps to 1 protein, 1 if it maps to 2 proteins, etc.
	--	Peptide_Sequence
	--	DeltaCn2
	--	y_score						Score of matching y-ions
	--	y_ions						Number of y-ions matched
	--	b_score						Score of matching b-ions
	--	b_ions						Number of b-ions matched
	--	Delta_Mass					Mass between peptide and parent ion
	--	Peptide_Intensity_Log(I)	Base-10 log of the peptide intensity
	--

	-- Note that additional columns may be added to #Tmp_Peptide_Import below based on @SynFileVersion
	CREATE TABLE #Tmp_Peptide_Import (
		Result_ID int NOT NULL ,
		Group_ID int NOT NULL ,
		Scan_Number int NULL ,
		Charge_State smallint NULL ,
		MH float NULL ,
		Peptide_Hyperscore real NULL ,
		Peptide_Log_EValue float NULL ,
		Multiple_Protein_Count int NULL ,
		Peptide varchar(850) NULL ,
		DeltaCn2 real NULL ,
		Y_Score real NULL ,
		Y_Ions smallint NULL ,
		B_Score real NULL ,
		B_Ions smallint NULL ,
		DelM real NULL ,
		Peptide_Log_Intensity real NULL
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #Tmp_Peptide_Import for job ' + @jobStr
		goto Done
	end

	If @SynFileVersion = '2011'
	Begin
		-- Add column DelM_PPM

		ALTER Table #Tmp_Peptide_Import ADD
			DelM_PPM real NULL
	End


	CREATE CLUSTERED INDEX #IX_Tmp_Peptide_Import_Result_ID ON #Tmp_Peptide_Import (Result_ID)
	CREATE INDEX #IX_Tmp_Peptide_Import_Scan_Number ON #Tmp_Peptide_Import (Scan_Number)


	-----------------------------------------------
	-- Create a table that will match up entries
	-- in #Tmp_Peptide_Import that are nearly identical,
	--  with the only difference being protein name
	-- Entries have matching:
	--	Scan, Charge, XCorr, DeltaCn2, and Peptide
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
	Set @LogMessage = 'Bulk load contents of _xt.txt file into temporary table; source path: ' + @PeptideSynFilePath
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

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


	-- Now that the data has been bulk-loaded, add DelM_PPM if necessary
	If @SynFileVersion = '2005'
	Begin
		-- Add column DelM_PPM

		ALTER Table #Tmp_Peptide_Import ADD
			DelM_PPM real NULL
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
		execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

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

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_PepProphet_Results]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_PepProphet_Results]

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
		Mass_Correction_Tag varchar(32) NOT NULL,					-- Note: The mass correction tags are limited to 32 characters when storing in T_Seq_Candidate_ModSummary
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
	--	 Protein_Expectation_Value_Log(e)	Base-10 log of the protein E-value
	--	 Protein Intensity_Log(I)			Base-10 log of the protein intensity; simply the sum of the intensity values of all peptide's found for this protein in this job

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
	-- of the PepProphet results file (if it exists)
	-----------------------------------------------
	CREATE TABLE #Tmp_PepProphet_Results (
		Result_ID int NOT NULL,					-- Corresponds to #Tmp_Peptide_Import.Result_ID
		FScore real NOT NULL,
		Probability real NOT NULL,
		negOnly tinyint NOT NULL
	)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #Tmp_PepProphet_Results for job ' + @jobStr
		goto Done
	end


	-----------------------------------------------
	-- Create a temporary table to hold contents
	-- of the MSGF results file (if it exists)
	-----------------------------------------------
	CREATE TABLE #Tmp_MSGF_Results (
		Result_ID int NOT NULL,						-- Corresponds to #Tmp_Peptide_Import.Result_ID
		Scan int NOT NULL,
		Charge smallint NOT NULL,
		Protein varchar(255) NULL,
		Peptide varchar(255) NOT NULL,
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
	-- Call LoadPeptideProphetResultsOneJob to load
	-- the PepProphet results file (if it exists)
	-----------------------------------------------
	Declare @PeptideProphetCountLoaded int
	Set @PeptideProphetCountLoaded = 0

	Set @LogMessage = 'Bulk load contents of peptide prophet file into temporary table; source path: ' + @PeptideProphetResultsFilePath
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

	exec @myError = LoadPeptideProphetResultsOneJob @job, @PeptideProphetResultsFilePath, @PeptideProphetCountLoaded output, @message output

	Set @LogMessage = 'Load complete; loaded ' + Convert(varchar(12), @PeptideProphetCountLoaded) + ' entries'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

	if @myError <> 0
	Begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling LoadPeptideProphetResultsOneJob for job ' + @jobStr
		Goto Done
	End


	-----------------------------------------------
	-- Call LoadMSGFResultsOneJob to load
	-- the MSGF results file (if it exists)
	-----------------------------------------------
	Declare @MSGFCountLoaded int
	Set @MSGFCountLoaded = 0

	Set @LogMessage = 'Bulk load contents of MSGF file into temporary table; source path: ' + @MSGFResultsFilePath
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

	exec @myError = LoadMSGFResultsOneJob @job, @MSGFResultsFilePath, @MSGFCountLoaded output, @message output

	Set @LogMessage = 'Load complete; loaded ' + Convert(varchar(12), @MSGFCountLoaded) + ' entries'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

	if @myError <> 0
	Begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling LoadMSGFResultsOneJob for job ' + @jobStr
		Goto Done
	End


	-----------------------------------------------
	-- Call LoadSeqInfoAndModsPart1 to load the SeqInfo related files if they exist
	-- If they do not exist, then @ResultToSeqMapCountLoaded will be 0;
	--  if an error occurs, then @result will be non-zero
	-----------------------------------------------
	--
	Declare @ResultToSeqMapCountLoaded int
	Declare @RaiseErrorIfSeqInfoFilesNotFound tinyint
	Set @ResultToSeqMapCountLoaded = 0
	Set @RaiseErrorIfSeqInfoFilesNotFound = 1

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

	If @ResultToSeqMapCountLoaded > 0 AND @ResultToSeqMapCountLoaded < @UnfilteredCountLoaded
	Begin
		Set @myError = 50002
		Set @message = 'Row count in the _ResultToSeqMap.txt file does not match the row count in the XTandem _xt.txt file for job ' + @jobStr + ' (' + Convert(varchar(12), @ResultToSeqMapCountLoaded) + ' vs. ' + Convert(varchar(12), @UnfilteredCountLoaded) + ')'
		Goto Done
	End


	-----------------------------------------------
	-- If the SeqInfo related files were not found, then we cannot continue
	-- LoadSeqInfoAndModsPart1 should have set @myError to a non-zero value and
	--  therefore jumped to Done in this SP.  Check @ResultToSeqMapCountLoaded now to validate this
	-----------------------------------------------
	If @ResultToSeqMapCountLoaded <= 0
	Begin
		Set @myError = 50002
		Set @message = 'The _ResultToSeqMap.txt file was empty for XTandem job ' + @jobStr + '; cannot continue'
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
		execute PostLogEntry 'Error', @message, 'LoadXTandemPeptidesBulk'
		Set @message = ''
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
			@XTandemHyperscoreComparison varchar(2),
			@XTandemHyperscoreThreshold real,
			@XTandemLogEValueComparison varchar(2),
			@XTandemLogEValueThreshold real,
			@PeptideProphetComparison varchar(2),		-- Only used if @PeptideProphetCountLoaded > 0
			@PeptideProphetThreshold float,				-- Only used if @PeptideProphetCountLoaded > 0
			@RankScoreComparison varchar(2),            -- Not used in this SP (since XTandem results always have RankScore = 1
			@RankScoreThreshold smallint,                -- Not used in this SP (since XTandem results always have RankScore = 1
			@MSGFSpecProbComparison varchar(2),			-- Used for Sequest, X!Tandem, or Inspect results
			@MSGFSpecProbThreshold real


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
										@MSGFSpecProbComparison = @MSGFSpecProbComparison OUTPUT, @MSGFSpecProbThreshold = @MSGFSpecProbThreshold OUTPUT

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
			execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

		INSERT INTO #Tmp_Peptide_Filter_Flags (Result_ID, Valid)
		SELECT Result_ID, 0
		FROM #Tmp_Peptide_Import
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		Set @LogMessage = 'Populated #Tmp_Peptide_Filter_Flags with ' + Convert(varchar(12), @myRowCount) + ' rows'
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

		-----------------------------------------------
		-- Mark peptides that pass the thresholds
		-----------------------------------------------

		While @CriteriaGroupMatch > 0
		Begin -- <CriteriaGroupMatch>
			Set @UsePeptideProphetFilter = 0
			If @PeptideProphetCountLoaded > 0
			Begin
				If @PeptideProphetComparison = '>' AND @PeptideProphetThreshold >= 0
					Set @UsePeptideProphetFilter = 1

				If @PeptideProphetComparison = '>=' AND @PeptideProphetThreshold > 0
					Set @UsePeptideProphetFilter = 1

				If @PeptideProphetComparison = '=' AND @PeptideProphetThreshold >= 0
					Set @UsePeptideProphetFilter = 1


				If @PeptideProphetComparison = '<' AND @PeptideProphetThreshold <= 1
					Set @UsePeptideProphetFilter = 1

				If @PeptideProphetComparison = '<=' AND @PeptideProphetThreshold < 1
					Set @UsePeptideProphetFilter = 1
			End

			Set @UseMSGFFilter = 0
			If @MSGFSpecProbComparison = '<' AND @MSGFSpecProbThreshold < 1
				Set @UseMSGFFilter = 1

			If @MSGFSpecProbComparison = '<=' AND @MSGFSpecProbThreshold < 1
				Set @UseMSGFFilter = 1


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
			Set @Sql = @Sql +          ' #Tmp_Peptide_SeqToProteinMap STPM ON PSI.Seq_ID_Local = STPM.Seq_ID_Local'

			If @UsePeptideProphetFilter = 1
				Set @Sql = @Sql +      ' INNER JOIN #Tmp_PepProphet_Results PPR ON TPI.Result_ID = PPR.Result_ID '

			If @UseMSGFFilter = 1
				Set @Sql = @Sql +      ' INNER JOIN #Tmp_MSGF_Results MSGF ON TPI.Result_ID = MSGF.Result_ID '

			-- Construct the Where clause
			Set @W = ''
			Set @W = @W +	' STPM.Cleavage_State ' + @CleavageStateComparison + Convert(varchar(6), @CleavageStateThreshold) + ' AND '
			Set @W = @W +	' STPM.Terminus_State ' + @TerminusStateComparison + Convert(varchar(6), @TerminusStateThreshold) + ' AND '
			Set @W = @W +	' TPI.Charge_State ' + @ChargeStateComparison + Convert(varchar(6), @ChargeStateThreshold) + ' AND '
			Set @W = @W +	' TPI.Peptide_Hyperscore ' + @XTandemHyperscoreComparison + Convert(varchar(11), @XTandemHyperscoreThreshold) + ' AND '
			Set @W = @W +	' PSI.Monoisotopic_Mass ' + @MassComparison + Convert(varchar(11), @MassThreshold) + ' AND '
			Set @W = @W +   ' TPI.Peptide_Log_EValue ' + @XTandemLogEValueComparison + Convert(varchar(11), @XTandemLogEValueThreshold)

			If @UsePeptideProphetFilter = 1
				Set @W = @W +      ' AND PPR.Probability ' + @PeptideProphetComparison + Convert(varchar(11), @PeptideProphetThreshold)

			If @UseMSGFFilter = 1
				Set @W = @W +      ' AND IsNull(MSGF.SpecProb, 1) ' + @MSGFSpecProbComparison + Convert(varchar(11), @MSGFSpecProbThreshold)

			Set @W = @W +    ' ) LookupQ ON LookupQ.Result_ID = TFF.Result_ID'

			-- Append the Where clause to @Sql
			Set @Sql = @Sql + ' WHERE ' + @W


			Set @LogMessage = 'Update #Tmp_Peptide_Filter_Flags for peptides passing the thresholds'
			If @LogLevel >= 3
				Set @LogMessage = @LogMessage + ': ' + @W

			if @LogLevel >= 2
				execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

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
				execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

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
											@MSGFSpecProbComparison = @MSGFSpecProbComparison OUTPUT, @MSGFSpecProbThreshold = @MSGFSpecProbThreshold OUTPUT
			If @myError <> 0
			Begin
				Set @Message = 'Error retrieving next entry from GetThresholdsForFilterSet in LoadXTandemPeptidesBulk'
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
			execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'
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

	Set @LogMessage = 'Deleted ' + Convert(varchar(12), @myRowCount) + ' entries from #Tmp_Peptide_Import'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'


	-----------------------------------------------
	-- Delete any existing results in T_Peptides, T_Score_XTandem
	-- T_Score_Discriminant, etc. for this analysis job
	-----------------------------------------------

	If Exists (SELECT * FROM T_Peptides WHERE Job = @Job) AND @UpdateExistingData = 0
	Begin
		Set @LogMessage = 'Call DeletePeptidesForJobAndResetToNew for Job ' + @jobStr
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

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
		execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

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
		execute PostLogEntry 'Error', @message, 'LoadXTandemPeptidesBulk'
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
		execute PostLogEntry 'Error', @message, 'LoadXTandemPeptidesBulk'
		Set @message = ''
	End

	-----------------------------------------------
	-- Check for proteins with long names
	-- MTS can handle protein names up to 255 characters long
	--  but SEQUEST will truncate protein names over 34 or 40 characters
	--  long (depending on the version) so we're checking here to notify
	--  the DMS admins if long protein names are encountered
	-- Even though we're loading XTandem data, we'll check for long
	--  protein names here to stay consistent with loading Sequest data
	-----------------------------------------------
	SELECT @LongProteinNameCount = COUNT(Distinct Reference)
	FROM #Tmp_Peptide_SeqToProteinMap
	WHERE Len(Reference) > 34 AND
		  NOT (	Reference LIKE 'reversed[_]%' OR	-- MTS reversed proteins
				Reference LIKE 'scrambled[_]%' OR	-- MTS scrambled proteins
				Reference LIKE '%[:]reversed' OR	-- X!Tandem decoy proteins
				Reference LIKE 'xxx.%'				-- Inspect reversed/scrambled proteins
			  )
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @LongProteinNameCount > 0
	Begin
		Set @message = 'Newly imported peptides found with protein names longer than 34 characters for job ' + @jobStr + ' (' + convert(varchar(11), @LongProteinNameCount) + ' distinct proteins)'
		execute PostLogEntry 'Error', @message, 'LoadXTandemPeptidesBulk'
		Set @message = ''
	End

	Set @LogMessage = 'Data verification complete'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

	-----------------------------------------------
	-- Generate a temporary table listing the minimum Result_ID value
	--  for each unique combination of Scan_Number, Charge_State, MH, Peptide
	-- For XTandem data there should not be any duplicate rows in #Tmp_Peptide_Import,
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
	ORDER BY MAX(Peptide_Hyperscore) DESC, TPI.Scan_Number, TPI.Peptide
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
		execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'


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
	declare @numAddedXTScores int
	declare @numAddedDiscScores int

	Set @LogMessage = 'Begin Transaction'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

	declare @transName varchar(32)
	set @transName = 'LoadXTandemPeptidesBulk'
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
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

			-----------------------------------------------
			-- Add new proteins to T_Proteins
			-----------------------------------------------
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
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

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
				1,						-- Number_of_Scans
				TPI.Charge_State,
				TPI.MH,
				TPI.Multiple_Protein_Count,
				TPI.Peptide,
				1 AS RankHit,
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
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

			SET IDENTITY_INSERT T_Peptides OFF


			-----------------------------------------------
			-- Copy selected contents of #Tmp_Peptide_Import
			--  into T_Score_Discriminant
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Populate T_Score_Discriminant using #Tmp_Peptide_Import'

			INSERT INTO T_Score_Discriminant
				(Peptide_ID, MScore, PassFilt)
			SELECT
				UR.Peptide_ID_New,
				10.75,		-- MScore is set to 10.75 for all XTandem results
				1			-- PassFilt is set to 1 for all XTandem results
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
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'


			-----------------------------------------------
			-- Copy selected contents of #Tmp_Peptide_Import
			-- into T_Score_XTandem
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Populate T_Score_XTandem using #Tmp_Peptide_Import'

			INSERT INTO T_Score_XTandem
				(Peptide_ID, Hyperscore, Log_EValue, DeltaCn2,
				 Y_Score, Y_Ions, B_Score, B_Ions, DelM, Intensity, Normalized_Score)
			SELECT
				UR.Peptide_ID_New,
				TPI.Peptide_Hyperscore,
				TPI.Peptide_Log_EValue,
				TPI.DeltaCn2,
				TPI.Y_Score,
				CASE WHEN TPI.Y_Ions > 255 THEN 255 ELSE TPI.Y_Ions END,
				TPI.B_Score,
				CASE WHEN TPI.B_Ions > 255 THEN 255 ELSE TPI.B_Ions END,
				TPI.DelM,
				POWER(Convert(real, 10), TPI.Peptide_Log_Intensity),								-- Convert from Log(I) to the raw intensity; must convert 10 to a real to avoid overflow errors
				dbo.udfHyperscoreToNormalizedScore(TPI.Peptide_Hyperscore, TPI.Charge_State)		-- Compute the Normalized Score using Hyperscore and Charge_State
			FROM #Tmp_Peptide_Import TPI INNER JOIN
				 #Tmp_Unique_Records UR ON TPI.Result_ID = UR.Result_ID
			ORDER BY UR.Peptide_ID_New
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				rollback transaction @transName
				set @message = 'Error inserting into T_Score_XTandem for job ' + @jobStr
				goto Done
			end
			Set @numAddedXTScores = @myRowCount

			Set @LogMessage = 'Populated T_Score_XTandem with ' + Convert(varchar(12), @myRowCount) + ' rows'
			if @LogLevel >= 2
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'


			-----------------------------------------------
			-- Copy selected contents of #Tmp_Peptide_Import and
			--  #Tmp_Peptide_SeqToProteinMap into T_Peptide_to_Protein_Map table;
			-- We shouldn't have to use the Group By when inserting, but if the synopsis file
			--  has multiple entries for the same combination of Scan_Number,
			--  Charge_State, MH, and Peptide pointing to the same Reference, then this
			--  will cause a primary key constraint error.
			-----------------------------------------------
			--
			INSERT INTO T_Peptide_to_Protein_Map (Peptide_ID, Ref_ID, Cleavage_State, Terminus_State, XTandem_Log_EValue)
			SELECT	UR.Peptide_ID_New, P.Ref_ID,
					MAX(IsNull(STPM.Cleavage_State, 0)),
					MAX(IsNull(STPM.Terminus_State, 0)),
					MIN(STPM.Protein_Log_EValue)
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
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'


			-----------------------------------------------
			-- Verify that all inserts have same number of rows
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Verify counts'

			Set @numAddedPeptides = IsNull(@numAddedPeptides, 0)
			Set @numAddedXTScores = IsNull(@numAddedXTScores, 0)
			Set @numAddedDiscScores = IsNull(@numAddedDiscScores, 0)

			if @numAddedPeptides <> @numAddedXTScores
			begin
				rollback transaction @transName
				set @message = 'Error in rowcounts for @numAddedPeptides vs @numAddedXTScores for job ' + @jobStr + '; ' + Convert(varchar(12), @numAddedPeptides) + ' <> ' + Convert(varchar(12), @numAddedXTScores)
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
						exec PostLogEntry 'Error', @LogMessage, 'LoadXTandemPeptidesBulk'
					End
					Else
					Begin
						exec PostLogEntry 'Warning', @LogMessage, 'LoadXTandemPeptidesBulk'
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
			    DelM_PPM = TPI.DelM_PPM
			FROM #Tmp_Peptide_Import TPI
			     INNER JOIN #Tmp_Unique_Records UR
			       ON TPI.Result_ID = UR.Result_ID
			     INNER JOIN T_Peptides Pep
			       ON Pep.Peptide_ID = UR.Peptide_ID_New
			WHERE IsNull(Pep.MH, -1) <> TPI.MH OR
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
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

			-----------------------------------------------
			-- No need to update T_Score_Discriminant
			-- since MScore is set to 10.75 and Passfilt is set to 1 for all XTandem results
			-----------------------------------------------

			-----------------------------------------------
			-- Update T_Score_XTandem
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Update T_Score_XTandem using #Tmp_Peptide_Import'

			UPDATE T_Score_XTandem
			SET Hyperscore = TPI.Peptide_Hyperscore,
	     		Log_EValue = TPI.Peptide_Log_EValue,
			    DeltaCn2 = TPI.DeltaCn2,
			    DelM = TPI.DelM,
			    Intensity = POWER(Convert(real, 10), TPI.Peptide_Log_Intensity),									-- Convert from Log(I) to the raw intensity; must convert 10 to a real to avoid overflow errors
				Normalized_Score = Case When TPI.Peptide_Hyperscore > -1
				                        THEN dbo.udfHyperscoreToNormalizedScore(TPI.Peptide_Hyperscore, TPI.Charge_State)
				                        ELSE IsNull(XT.Normalized_Score, 0)
				                        End						-- Compute the Normalized Score using Peptide_Hyperscore and Charge_State
			FROM #Tmp_Peptide_Import TPI
			     INNER JOIN #Tmp_Unique_Records UR
			       ON TPI.Result_ID = UR.Result_ID
			     INNER JOIN T_Peptides Pep
			       ON Pep.Peptide_ID = UR.Peptide_ID_New
			     INNER JOIN T_Score_XTandem XT
			       ON Pep.Peptide_ID = XT.Peptide_ID
			WHERE IsNull(XT.Hyperscore, -99) <> TPI.Peptide_Hyperscore OR
			      IsNull(XT.Log_EValue, 99) <> TPI.Peptide_Log_EValue OR
			      IsNull(XT.DeltaCn2, -1) <> TPI.DeltaCn2 OR
			      IsNull(XT.DelM, -9999) <> TPI.DelM OR
			      IsNull(XT.Intensity, -1) <> POWER(Convert(real, 10), TPI.Peptide_Log_Intensity) OR
			      IsNull(XT.Normalized_Score, -99) <> dbo.udfHyperscoreToNormalizedScore(TPI.Peptide_Hyperscore, TPI.Charge_State)
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				rollback transaction @transName
				set @message = 'Error updating T_Score_XTandem for job ' + @jobStr
				goto Done
			end
			Set @numAddedXTScores = @myRowCount

			Set @LogMessage = 'Updated ' + Convert(varchar(12), @myRowCount) + ' rows in T_Score_XTandem'
			if @LogLevel >= 2
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'


			-----------------------------------------------
			-- Change Hyperscore to -Hyperscore and Normalized_Score to -Normalized_Score for peptides that are in T_Score_XTandem yet are not in #Tmp_Peptide_Import
			-- This will commonly be the case if the data was loosely filtered when it was initially loaded but was
			-- filtered out of #Tmp_Peptide_Import on this load
			-----------------------------------------------
			--
			UPDATE T_Score_XTandem
			SET Hyperscore = -ABS(XT.Hyperscore),
			    Normalized_Score = -ABS(Normalized_Score)
			FROM T_Peptides Pep
			     INNER JOIN T_Score_XTandem XT
			       ON Pep.Peptide_ID = XT.Peptide_ID
			     LEFT OUTER JOIN #Tmp_Unique_Records UR
			       ON Pep.Peptide_ID = UR.Peptide_ID_New
			WHERE Pep.Job = @Job AND
			      (XT.Hyperscore > 0 OR XT.Normalized_Score > 0) AND
			      UR.Peptide_ID_New IS NULL
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			If @myRowCount > 0
			Begin
				Set @LogMessage = 'Changed Hyperscore and Normalized_Score to a negative value for ' + Convert(varchar(12), @myRowCount) + ' entries for job ' + @jobStr + ' since the peptides no longer pass filters'
				execute PostLogEntry 'Warning', @LogMessage, 'LoadXTandemPeptidesBulk'
			End

			-----------------------------------------------
			-- Note: we do not update T_Proteins or T_Peptide_to_Protein_Map
			-----------------------------------------------

			SELECT @numLoaded = COUNT(*)
			FROM #Tmp_Unique_Records

		End -- </a2>

		-----------------------------------------------
		-- Commit changes to T_Peptides, T_Score_XTandem, etc. if we made it this far
		-----------------------------------------------
		--
		Set @CurrentLocation = 'Commit changes'

		commit transaction @transName

		Set @LogMessage = 'Transaction committed'
		if @LogLevel >= 2
		Begin
			execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'
			execute PostLogEntryFlushCache
		End

	End Try
	Begin Catch
		if @@TranCount > 0
			rollback transaction

		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'LoadXTandemPeptidesBulk')
		Set @CurrentLocation = @CurrentLocation + '; job ' + @jobStr

		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output

		If @myError = 0
			Set @myError = 60012
	End Catch


	-----------------------------------------------
	-- Now that the transaction is commited, we will
	-- store the peptide prophet and/or MSGF values in T_Score_Discriminant
	-- We do this outside of the transaction since this can be a slow process
	-----------------------------------------------

	-----------------------------------------------
	-- Populate #Tmp_Peptide_Import_MatchedEntries with a list of equivalent rows in #Tmp_Peptide_Import
	-- This table is used by StorePeptideProphetValues and StoreMSGFValues
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
	          TPI2.Peptide_Hyperscore = TPI.Peptide_Hyperscore AND
	          TPI2.DeltaCn2 = TPI.DeltaCn2 AND
	          TPI2.Peptide = TPI.Peptide AND
	          TPI2.Result_ID <> TPI.Result_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


	Set @LogMessage = 'Populated #Tmp_Peptide_Import_MatchedEntries with ' + Convert(varchar(12), @myRowCount) + ' rows'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

	-----------------------------------------------
	-- Populate the Peptide Prophet columns in T_Score_Discriminant
	-----------------------------------------------
	--
	If @PeptideProphetCountLoaded > 0
	Begin
		Set @PepProphetFileFound = 1


		Exec StorePeptideProphetValues @job, @numAddedDiscScores,
									   @LogLevel, @LogMessage,
									   @UsingPhysicalTempTables,
									   @UpdateExistingData,
									   @infoOnly=0, @message=@message output

	End
	Else
	Begin
		Set @PeptideProphetCountLoaded = 0

		-----------------------------------------------
		-- Compute a pseudo peptide prophet value using Log_EValue
		-----------------------------------------------
		--
		UPDATE T_Score_Discriminant
		SET Peptide_Prophet_Probability = CASE WHEN XT.Hyperscore > 0
                                               THEN dbo.udfLogEValueToPeptideProphetEstimate(XT.Log_EValue)
                                               ELSE Null END
		FROM T_Peptides P INNER JOIN
		     T_Score_XTandem XT ON P.Peptide_ID = XT.Peptide_ID INNER JOIN
		     T_Score_Discriminant D ON P.Peptide_ID = D.Peptide_ID
		WHERE P.Job = @job AND D.Peptide_Prophet_Probability Is Null
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
	End


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
			execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

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
		execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'


	-----------------------------------------------
	-- If @ResultToSeqMapCountLoaded > 0, then call LoadSeqInfoAndModsPart2
	--  to populate the Candidate Sequence tables (this should always be true for X!Tandem)
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
			execute PostLogEntry 'Progress', @LogMessage, 'LoadXTandemPeptidesBulk'

	End

Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[LoadXTandemPeptidesBulk] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[LoadXTandemPeptidesBulk] TO [MTS_DB_Lite] AS [dbo]
GO
