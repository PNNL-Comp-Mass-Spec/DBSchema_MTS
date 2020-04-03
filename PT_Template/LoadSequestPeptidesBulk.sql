/****** Object:  StoredProcedure [dbo].[LoadSequestPeptidesBulk] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure LoadSequestPeptidesBulk
/****************************************************
**
**	Desc:
**		Load peptides from synopsis file into peptides table
**		for given analysis job using bulk loading techniques
**
**		Note: This routine will not load peptides with an XCorr value
**			  below minimum thresholds (as defined by @FilterSetID)
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	grk
**	Date:	11/11/2001
**			07/03/2004 mem - Modified procedure to store data in new Peptide DB tables
**						   - Added check for existing results for this job in the Peptide DB tables; results will be deleted if existing
**			07/16/2004 grk - Use new sequest peptide file extractor (discriminant scoring)
**			07/21/2004 mem - Added additional @myError statements
**			08/06/2004 mem - Changed from MH > @LMWtoHMWTransition to MH >= @LMWtoHMWTransition and added IsNull when determining @MaxPeptideID
**			08/24/2004 mem - Switched to using @FilterSetID; added parameter @numSkipped
**			09/10/2004 mem - Added new filter field: @DiscriminantInitialFilter
**			09/14/2004 mem - Added parsing out of protein references to reduce duplicate data in T_Peptides
**			01/03/2005 mem - Now passing 0 to @DropAndAddConstraints when calling DeletePeptidesForJobAndResetToNew
**			01/27/2005 mem - Fixed bug with @DiscriminantScoreComparison variable length
**			03/26/2005 mem - Added optional call to CalculateCleavageState
**			03/26/2005 mem - Updated call to GetThresholdsForFilterSet to include @ProteinCount and @TerminusState criteria
**			12/11/2005 mem - Updated call to GetThresholdsForFilterSet to include XTandem criteria
**						   - Updated population of #Tmp_Unique_Records to guarantee the peptides are ordered by XCorr descending and Scan_Number ascending
**			01/15/2006 mem - Added parameters @PeptideSeqInfoFilePath and @PeptideSeqModDetailsFilePath and added call to LoadSeqInfoAndModsPart1
**			01/25/2006 mem - Now considering @CleavageState and @TerminusState when filtering; if the results being loaded to not have a SeqInfo.txt file, then the cleavage and terminus states are computed in this SP
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
**			10/10/2007 mem - Now excluding reversed or scrambled proteins when looking for long protein names
**			08/27/2008 mem - Added additional logging when LogLevel >= 2
**			09/24/2008 mem - Now allowing for @FilterSetID to be 0 (which will disable any filtering)
**			09/22/2009 mem - Now calling UpdatePeptideCleavageStateMax
**			12/14/2009 mem - Now treating a mismatch between _ResultToSeqMap and _syn.txt as a non-fatal error, provided _ResultToSeqMap has 1 or more entries
**			07/23/2010 mem - Added support for MSGF results
**						   - Added 'xxx.%' as a potential prefix for reversed proteins
**			02/01/2011 mem - Added support for MSGF filtering
**			02/25/2011 mem - Expanded SpecProbNote to varchar(512) in #Tmp_MSGF_Results
**			08/05/2011 mem - Added Try/Catch handling around the population of T_Peptides and related tables
**			08/19/2011 mem - Added parameters @SynFileColCount and @SynFileHeader
						   - Now populating columns RankHit and DelM_PPM
**			08/23/2011 mem - Switched DelM_PPM from float to real
**			09/14/2011 mem - Now using MSGF filter even if @MSGFCountLoaded = 0
**			12/24/2011 mem - Added support for updating existing data as an alternative to loading new data
**						   - Added switch @UpdateExistingData
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			02/20/2012 mem - Now comparing clean peptide sequence if mismatches are found when updating existing data
**			12/04/2012 mem - Now populating #Tmp_Peptide_ModSummary
**			12/06/2012 mem - Expanded @message to varchar(1024)
**          04/09/2020 mem - Expand Mass_Correction_Tag to varchar(32)
**
*****************************************************/
(
	@PeptideSynFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn.txt',
	@PeptideResultToSeqMapFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn_ResultToSeqMap.txt',
	@PeptideSeqInfoFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn_SeqInfo.txt',
	@PeptideSeqModDetailsFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn_ModDetails.txt',
	@PeptideSeqToProteinMapFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn_SeqToProteinMap.txt',
	@PeptideProphetResultsFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn_PepProphet.txt',
	@MSGFResultsFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn_MSGF.txt',
	@Job int,
	@FilterSetID int,
	@LineCountToSkip int=0,
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

	declare @LongProteinNameCount int
	set @LongProteinNameCount = 0

	declare @UsePeptideProphetFilter tinyint
	declare @UseRankScoreFilter tinyint
	declare @UseMSGFFilter tinyint

	declare @LogLevel int
	declare @LogMessage varchar(512)

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

	Set @LogMessage = 'Loading Sequest results for Job ' + @jobStr + '; create temporary tables'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

	-----------------------------------------------
	-- Drop physical tables if required
	-----------------------------------------------

	If @UsingPhysicalTempTables = 1
	Begin
		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Peptide_Filter_Flags]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Peptide_Filter_Flags]

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Peptide_Import]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Peptide_Import]

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Peptide_Import_MatchedEntries]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Peptide_Import_MatchedEntries]

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Peptide_Import_Unfiltered]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Peptide_Import_Unfiltered]

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Unique_Records]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Unique_Records]

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Unfiltered_Unique_Records]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Unfiltered_Unique_Records]

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Peptide_Cleavage_State]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Peptide_Cleavage_State]

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Peptide_Addnl_Cleavage_State]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Peptide_Addnl_Cleavage_State]
	End

	-----------------------------------------------
	-- Create temporary table to hold contents
	-- of Sequest synopsis file (_syn.txt)
	-----------------------------------------------
	--
	Declare @SynFileVersion varchar(64)
	Set @SynFileVersion = ''

	If (@SynFileColCount = 19 And @SynFileHeader Like '%PassFilt%' ) Or
	    @SynFileColCount = 0 Or @SynFileHeader = ''
	Begin
		Set @SynFileVersion = '2005'
	End

	If @SynFileVersion = ''
	Begin
		If @SynFileColCount = 20 And @SynFileHeader Like '%Ions_Observed%'
			Set @SynFileVersion = '2011'
	End

	If @SynFileVersion = ''
	Begin
		-- Unrecognized version
		if @myError = 52005
		begin
			set @message = 'Unrecognized Synopsis file format for Job ' + @jobStr
			Set @message = @message + '; file contains ' + convert(varchar(12), @SynFileColCount) + ' columns (Expecting 19 or 20 columns)'
			goto Done
		end
	End

	-- Note that additional columns will be added to #Tmp_Peptide_Import below based on @SynFileVersion
	CREATE TABLE #Tmp_Peptide_Import (
	   Result_ID int NOT NULL,
	   Scan_Number int NULL,
	   Number_Of_Scans smallint NULL,
	   Charge_State smallint NULL,
	   MH float NULL,
	   XCorr real NULL,
	   DeltaCn real NULL,
	   Sp float NULL,
	   Reference varchar (255) NULL,
	   Multiple_Protein_Count int NULL,
	   Peptide varchar (850) NULL,
	   DeltaCn2 real NULL,
	   RankSp real NULL,
	   RankXc smallint NULL,
	   DelM float NULL,
	   RatioXc real NULL
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #Tmp_Peptide_Import for job ' + @jobStr
		goto Done
	end

	If @SynFileVersion = '2005'
	Begin
		/***
			Result_ID	Unique Row ID
			Scan		Scan Number
			Num			Number of Scans
			Chg			Charge State
			MH			Average mass (M+H)+ of the peptide as computed by Sequest
			XCorr
			DeltaCn
			Sp
			Ref.    	ORF Reference
			MO      	Number of ORF references beyond first one
			Peptide 	Peptide sequence
			DeltaCn2	delcn EFS convention
			RankSp  	Rank from Sp score
			RankXc  	Rank based XCorr
			DelM    	Error parent ion
			XcRatio 	Ratio Xcorr(n)/Xcorr(top)
			PassFilt  	Filter(0=fail, other=pass)
			MScore  	Fragmentation Score
			NTT	  		Number of tryptic termini, aka Cleavage_State (NTT does not treat tryptic terminii correctly)

		***/

		ALTER Table #Tmp_Peptide_Import ADD
			PassFilt int NULL,
			MScore real NULL,
			Cleavage_State smallint NULL

	End

	If @SynFileVersion = '2011'
	Begin
		/***
			Result_ID	Unique Row ID
			Scan		Scan Number
			Num			Number of Scans
			Chg			Charge State
			MH			Average mass (M+H)+ of the peptide as computed by Sequest
			XCorr
			DeltaCn
			Sp
			Ref.    	ORF Reference
			MO      	Number of ORF references beyond first one
			Peptide 	Peptide sequence
			DeltaCn2	delcn EFS convention
			RankSp  	Rank from Sp score
			RankXc  	Rank based XCorr
			DelM    	Error parent ion
			XcRatio 	Ratio Xcorr(n)/Xcorr(top)
			Ions_Observed
			Ions_Expected
			NTT	  		Number of tryptic termini, aka Cleavage_State (NTT does not treat tryptic terminii correctly)
			DelM_PPM

		***/

		ALTER Table #Tmp_Peptide_Import ADD
			Ions_Observed int NULL,
			Ions_Expected int NULL,
			Cleavage_State smallint NULL,
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
	-- Create a table for holding re-computed cleavage
	-- and terminus state values
	-----------------------------------------------
	CREATE TABLE #Tmp_Peptide_Cleavage_State (
		Result_ID int NOT NULL ,
		Cleavage_State tinyint NULL ,
		Terminus_State tinyint NULL
	)

	CREATE CLUSTERED INDEX #IX_Tmp_Peptide_Cleavage_State_Result_ID ON #Tmp_Peptide_Cleavage_State (Result_ID)


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
	Set @LogMessage = 'Bulk load contents of synopsis file into temporary table; source path: ' + @PeptideSynFilePath
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

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
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

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
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

	exec @myError = LoadPeptideProphetResultsOneJob @job, @PeptideProphetResultsFilePath, @PeptideProphetCountLoaded output, @message output

	Set @LogMessage = 'Load complete; loaded ' + Convert(varchar(12), @PeptideProphetCountLoaded) + ' entries'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

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
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

	exec @myError = LoadMSGFResultsOneJob @job, @MSGFResultsFilePath, @MSGFCountLoaded output, @message output

	Set @LogMessage = 'Load complete; loaded ' + Convert(varchar(12), @MSGFCountLoaded) + ' entries'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

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
	Declare @ExpectedResultToSeqMapCount int
	Declare @RaiseErrorIfSeqInfoFilesNotFound tinyint
	Set @ResultToSeqMapCountLoaded = 0
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
		Set @ExpectedResultToSeqMapCount = 0
		SELECT @ExpectedResultToSeqMapCount = COUNT(*)
		FROM (	SELECT Scan_Number, Number_Of_Scans, Charge_State, MH, Peptide
				FROM #Tmp_Peptide_Import
				GROUP BY Scan_Number, Number_Of_Scans, Charge_State, MH, Peptide
			 ) LookupQ

		If @ResultToSeqMapCountLoaded <> @ExpectedResultToSeqMapCount
		Begin
			Set @message = 'Row count in the _ResultToSeqMap.txt file does not match the expected unique row count determined for the Sequest _syn.txt file for job ' + @jobStr + ' (' + Convert(varchar(12), @ResultToSeqMapCountLoaded) + ' vs. ' + Convert(varchar(12), @ExpectedResultToSeqMapCount) + ')'

			-- @ResultToSeqMapCountLoaded is non-zero; record this as a warning, but flag it as type 'Error' so it shows up in the daily e-mail
			Set @message = 'Warning: ' + @message
			execute PostLogEntry 'Error', @message, 'LoadSequestPeptidesBulk'
			Set @message = ''
		End

		Set @SeqCandidateFilesFound = 1
	End


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
		execute PostLogEntry 'Error', @message, 'LoadSequestPeptidesBulk'
		Set @message = ''
	End

	-----------------------------------------------
	-- Generate a temporary table listing the
	--  minimum Result_ID value for each unique
	--  combination of Scan_Number, Charge_State, MH, Peptide
	-- This table is different than #Tmp_Unique_Records in that
	--  it uses the unfiltered data from #Tmp_Peptide_Import
	--  while #Tmp_Unique_Records uses the filtered data and populates
	--  Peptide_ID_New
	-----------------------------------------------

	CREATE TABLE #Tmp_Unfiltered_Unique_Records (
		Result_ID int NOT NULL ,
		Scan_Number int NOT NULL ,
		Number_of_Scans int NOT NULL ,
		Charge_State smallint NOT NULL ,
		MH float NOT NULL ,
		Peptide varchar (850) NOT NULL
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #Tmp_Unfiltered_Unique_Records for job ' + @jobStr
		goto Done
	end

	CREATE CLUSTERED INDEX #IX_Tmp_Unfiltered_Unique_Records_Result_ID ON #Tmp_Unfiltered_Unique_Records (Result_ID)
	CREATE INDEX #IX_Tmp_Unfiltered_Unique_Records_MH ON #Tmp_Unfiltered_Unique_Records (MH)
	CREATE INDEX #IX_Tmp_Unfiltered_Unique_Records_Scan_Number ON #Tmp_Unfiltered_Unique_Records (Scan_Number)


	-----------------------------------------------
	-- Populate #Tmp_Unfiltered_Unique_Records
	-----------------------------------------------
	--
	Set @LogMessage = 'Populate #Tmp_Unfiltered_Unique_Records'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'


	If @ResultToSeqMapCountLoaded > 0
	Begin
		INSERT INTO #Tmp_Unfiltered_Unique_Records (Result_ID, Scan_Number, Number_Of_Scans, Charge_State, MH, Peptide)
		SELECT MIN(TPI.Result_ID), TPI.Scan_Number, TPI.Number_Of_Scans, TPI.Charge_State, TPI.MH, TPI.Peptide
		FROM #Tmp_Peptide_Import TPI INNER JOIN
			 #Tmp_Peptide_ResultToSeqMap RTSM ON TPI.Result_ID = RTSM.Result_ID
		GROUP BY TPI.Scan_Number, TPI.Number_Of_Scans, TPI.Charge_State, TPI.MH, TPI.Peptide
		ORDER BY MAX(TPI.XCorr) DESC, TPI.Scan_Number, TPI.Peptide
	End
	Else
	Begin
		INSERT INTO #Tmp_Unfiltered_Unique_Records (Result_ID, Scan_Number, Number_Of_Scans, Charge_State, MH, Peptide)
		SELECT MIN(Result_ID), Scan_Number, Number_Of_Scans, Charge_State, MH, Peptide
		FROM #Tmp_Peptide_Import
		GROUP BY Scan_Number, Number_Of_Scans, Charge_State, MH, Peptide
		ORDER BY MAX(XCorr) DESC, Scan_Number, Peptide
	End
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem populating temporary table #Tmp_Unfiltered_Unique_Records ' + @jobStr
		goto Done
	end
	--
	if @myRowCount = 0
	Begin
		set @myError = 50005
		set @message = '#Tmp_Unfiltered_Unique_Records table populated with no records for job ' + @jobStr
		goto Done
	End

	Set @LogMessage = 'Populated #Tmp_Unfiltered_Unique_Records with ' + Convert(varchar(12), @myRowCount) + ' rows'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

	-----------------------------------------------
	-- If the SeqInfo related files were found, then populate #Tmp_Peptide_Cleavage_State using #Tmp_Peptide_SeqToProteinMap
	-- Otherwise, calculate the cleavage state and terminus state of the peptides
	-----------------------------------------------
	If @ResultToSeqMapCountLoaded > 0
	Begin
		INSERT INTO #Tmp_Peptide_Cleavage_State (Result_ID, Cleavage_State, Terminus_State)
		SELECT TPI.Result_ID, MAX(ISNULL(STPM.Cleavage_State, 0)), MAX(ISNULL(STPM.Terminus_State, 0))
		FROM #Tmp_Unfiltered_Unique_Records UUR INNER JOIN
			 #Tmp_Peptide_Import TPI ON UUR.Result_ID = TPI.Result_ID INNER JOIN
		     #Tmp_Peptide_ResultToSeqMap RTSM ON TPI.Result_ID = RTSM.Result_ID INNER JOIN
		    #Tmp_Peptide_SeqInfo PSI ON RTSM.Seq_ID_Local = PSI.Seq_ID_Local INNER JOIN
		     #Tmp_Peptide_SeqToProteinMap STPM ON PSI.Seq_ID_Local = STPM.Seq_ID_Local
		GROUP BY TPI.Result_ID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		Set @LogMessage = 'Populated #Tmp_Peptide_Cleavage_State with ' + Convert(varchar(12), @myRowCount) + ' rows (used the SeqInfo file data)'
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

	End
	Else
	Begin

		-- Populate #Tmp_Peptide_Cleavage_State using TPI.Cleavage_State as a starting point for cleavage state
		--
		INSERT INTO #Tmp_Peptide_Cleavage_State (Result_ID, Cleavage_State, Terminus_State)
		SELECT TPI.Result_ID, TPI.Cleavage_State, 0
		FROM #Tmp_Unfiltered_Unique_Records UUR INNER JOIN
			 #Tmp_Peptide_Import TPI ON UUR.Result_ID = TPI.Result_ID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		Set @LogMessage = 'Populated #Tmp_Peptide_Cleavage_State with ' + Convert(varchar(12), @myRowCount) + ' rows (SeqInfo file data is not available)'
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

		-- Define Terminus_State
		-- Note that this update query matches that in CalculateCleavageState
		--
		UPDATE #Tmp_Peptide_Cleavage_State
		SET Terminus_State = CASE WHEN TPI.Peptide LIKE '-.%.-' THEN 3
							 WHEN TPI.Peptide LIKE '-.%' THEN 1
							 WHEN TPI.Peptide LIKE '%.-' THEN 2
							 ELSE 0
							 END
		FROM #Tmp_Peptide_Cleavage_State PCS INNER JOIN
			 #Tmp_Peptide_Import TPI ON PCS.Result_ID = TPI.Result_ID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		Set @LogMessage = 'Defined peptide terminus state'
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

		-- Define Cleavage State
		-- Note that this update query matches that in CalculateCleavageState
		--
		UPDATE #Tmp_Peptide_Cleavage_State
		SET Cleavage_State =
			CASE WHEN TPI.Peptide LIKE '[KR].%[KR].[^P]' AND TPI.Peptide NOT LIKE '_.P%' THEN 2		-- Fully tryptic
			WHEN TPI.Peptide LIKE '[KR].%[KR][^A-Z].[^P]' AND TPI.Peptide NOT LIKE '_.P%' THEN 2	-- Fully tryptic, allowing modified K or R
			WHEN TPI.Peptide LIKE '-.%[KR].[^P]' THEN 2				-- Fully tryptic at the N-terminus
			WHEN TPI.Peptide LIKE '-.%[KR][^A-Z].[^P]' THEN 2		-- Fully tryptic at the N-terminus, allowing modified K or R
			WHEN TPI.Peptide LIKE '[KR].[^P]%.-' THEN 2				-- Fully tryptic at C-terminus
			WHEN TPI.Peptide LIKE '-.%.-' THEN 2					-- Label sequences spanning the entire protein as fully tryptic
			WHEN TPI.Peptide LIKE '[KR].[^P]%.%' THEN 1				-- Partially tryptic
			WHEN TPI.Peptide LIKE '%.%[KR].[^P-]' THEN 1			-- Partially tryptic
			WHEN TPI.Peptide LIKE '%.%[KR][^A-Z].[^P-]' THEN 1		-- Partially tryptic, allowing modified K or R
			ELSE 0
			END
		FROM #Tmp_Peptide_Cleavage_State PCS INNER JOIN
			 #Tmp_Peptide_Import TPI ON PCS.Result_ID = TPI.Result_ID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		Set @LogMessage = 'Defined peptide cleavage state'
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

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
			@HighNormalizedScoreComparison varchar(2),
			@HighNormalizedScoreThreshold float,
			@CleavageStateComparison varchar(2),
			@CleavageStateThreshold tinyint,
			@PeptideLengthComparison varchar(2),		-- Not used in this SP
			@PeptideLengthThreshold smallint,			-- Not used in this SP
			@MassComparison varchar(2),
			@MassThreshold float,
			@DeltaCnComparison varchar(2),
			@DeltaCnThreshold float,
			@DeltaCn2Comparison varchar(2),				-- Not used in this SP
			@DeltaCn2Threshold float,					-- Not used in this SP
			@DiscriminantScoreComparison varchar(2),	-- Not used in this SP
			@DiscriminantScoreThreshold float,			-- Not used in this SP
			@NETDifferenceAbsoluteComparison varchar(2),-- Not used in this SP
			@NETDifferenceAbsoluteThreshold float,		-- Not used in this SP
			@DiscriminantInitialFilterComparison varchar(2),
			@DiscriminantInitialFilterThreshold float,
			@ProteinCountComparison varchar(2),			-- Not used in this SP
			@ProteinCountThreshold int,					-- Not used in this SP
			@TerminusStateComparison varchar(2),
			@TerminusStateThreshold tinyint,
			@XTandemHyperscoreComparison varchar(2),	-- Not used in this SP
			@XTandemHyperscoreThreshold real,			-- Not used in this SP
			@XTandemLogEValueComparison varchar(2),		-- Not used in this SP
			@XTandemLogEValueThreshold real,			-- Not used in this SP
			@PeptideProphetComparison varchar(2),		-- Only used if @PeptideProphetCountLoaded > 0
			@PeptideProphetThreshold float,				-- Only used if @PeptideProphetCountLoaded > 0
			@RankScoreComparison varchar(2),
			@RankScoreThreshold smallint,
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
		-- We populate it with all data in #Tmp_Peptide_Import
		--  though we'll only test the data in #Tmp_Peptide_Cleavage_State
		--  (which is inherently filtered on the data in #Tmp_Unfiltered_Unique_Records)
		--  against the filters
		-----------------------------------------------
		--

		Set @LogMessage = 'Populate #Tmp_Peptide_Filter_Flags using #Tmp_Peptide_Import'
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

		INSERT INTO #Tmp_Peptide_Filter_Flags (Result_ID, Valid)
		SELECT Result_ID, 0
		FROM #Tmp_Peptide_Import
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		Set @LogMessage = 'Populated #Tmp_Peptide_Filter_Flags with ' + Convert(varchar(12), @myRowCount) + ' rows'
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

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

			Set @UseRankScoreFilter = 1
			If @RankScoreComparison = '>=' AND @RankScoreThreshold <= 1
				Set @UseRankScoreFilter = 0

			If @RankScoreComparison = '>' AND @RankScoreThreshold <= 0
				Set @UseRankScoreFilter = 0

			-- Construct the Sql Update Query
			--
			Set @Sql = ''
			Set @Sql = @Sql + ' UPDATE #Tmp_Peptide_Filter_Flags'
			Set @Sql = @Sql + ' SET Valid = 1'
			Set @Sql = @Sql + ' FROM #Tmp_Peptide_Filter_Flags TFF INNER JOIN'
			Set @Sql = @Sql +      ' #Tmp_Peptide_Import TPI ON TFF.Result_ID = TPI.Result_ID INNER JOIN'
			Set @Sql = @Sql +      ' #Tmp_Peptide_Cleavage_State PCS ON TPI.Result_ID = PCS.Result_ID'

			If @UsePeptideProphetFilter = 1
				Set @Sql = @Sql +      ' INNER JOIN #Tmp_PepProphet_Results PPR ON TPI.Result_ID = PPR.Result_ID '

			If @UseMSGFFilter = 1
				Set @Sql = @Sql +      ' INNER JOIN #Tmp_MSGF_Results MSGF ON TPI.Result_ID = MSGF.Result_ID '

			-- Construct the Where clause
			Set @W = ''
			Set @W = @W +	' PCS.Cleavage_State ' + @CleavageStateComparison + Convert(varchar(6), @CleavageStateThreshold) + ' AND '
			Set @W = @W +	' PCS.Terminus_State ' + @TerminusStateComparison + Convert(varchar(6), @TerminusStateThreshold) + ' AND '
			Set @W = @W +	' TPI.Charge_State ' + @ChargeStateComparison + Convert(varchar(6), @ChargeStateThreshold) + ' AND '
			Set @W = @W +	' TPI.XCorr ' + @HighNormalizedScoreComparison +  Convert(varchar(11), @HighNormalizedScoreThreshold) + ' AND '
			Set @W = @W +	' TPI.MH ' + @MassComparison + Convert(varchar(11), @MassThreshold) + ' AND '
			Set @W = @W +	' TPI.DeltaCn ' + @DeltaCnComparison + Convert(varchar(11), @DeltaCnThreshold)

			If @SynFileVersion = '2005'
				Set @W = @W + ' AND TPI.PassFilt ' + @DiscriminantInitialFilterComparison + Convert(varchar(11), @DiscriminantInitialFilterThreshold)


			If @UseRankScoreFilter = 1
				Set @W = @W + ' AND TPI.RankXc ' + @RankScoreComparison + Convert(varchar(11), @RankScoreThreshold)

			If @UsePeptideProphetFilter = 1
				Set @W = @W + ' AND PPR.Probability ' + @PeptideProphetComparison + Convert(varchar(11), @PeptideProphetThreshold)

			If @UseMSGFFilter = 1
				Set @W = @W + ' AND IsNull(MSGF.SpecProb, 1) ' + @MSGFSpecProbComparison + Convert(varchar(11), @MSGFSpecProbThreshold)

			-- Append the Where clause to @Sql
			Set @Sql = @Sql + ' WHERE ' + @W


			Set @LogMessage = 'Update #Tmp_Peptide_Filter_Flags for peptides passing the thresholds'
			If @LogLevel >= 3
				Set @LogMessage = @LogMessage + ': ' + @W

			if @LogLevel >= 2
				execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

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
				execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

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
				Set @Message = 'Error retrieving next entry from GetThresholdsForFilterSet in LoadSequestPeptidesBulk'
				Goto Done
			End

		End -- </CriteriaGroupMatch>


		-----------------------------------------------
		-- Update the Valid flag in #Tmp_Peptide_Filter_Flags
		--  for those peptides in #Tmp_Peptide_Import that were
		--  not evaluated against the import filters but match
		--  Scan_Number, Number_of_Scans, Charge_State, MH, and Peptide
		--  with those that already have Valid = 1
		-----------------------------------------------
		UPDATE #Tmp_Peptide_Filter_Flags
		SET Valid = 1
		FROM #Tmp_Peptide_Filter_Flags PFF INNER JOIN
			#Tmp_Peptide_Import TPI ON TPI.Result_ID = PFF.Result_ID INNER JOIN
			(	SELECT TPI.Scan_Number, TPI.Number_of_Scans, TPI.Charge_State, TPI.MH, TPI.Peptide
				FROM #Tmp_Peptide_Filter_Flags TFF INNER JOIN
					#Tmp_Peptide_Import TPI ON TFF.Result_ID = TPI.Result_ID
				WHERE TFF.Valid = 1
			) LookupQ ON
			TPI.Scan_Number = LookupQ.Scan_Number AND
			TPI.Number_Of_Scans = LookupQ.Number_Of_Scans AND
			TPI.Charge_State = LookupQ.Charge_State AND
			TPI.MH = LookupQ.MH AND
			TPI.Peptide = LookupQ.Peptide
		WHERE PFF.Valid = 0
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		Set @LogMessage = 'Set Valid to 1 in #Tmp_Peptide_Filter_Flags for ' + Convert(varchar(12), @myRowCount) + ' peptides'
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

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
			execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'
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

	Set @LogMessage = 'Deleted ' + Convert(varchar(12), @myRowCount) + ' entries from #Tmp_Peptide_Import'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'


	-----------------------------------------------
	-- Delete any existing results in T_Peptides, T_Score_Sequest
	-- T_Score_Discriminant, etc. for this analysis job
	-----------------------------------------------

	If Exists (SELECT * FROM T_Peptides WHERE Job = @Job) AND @UpdateExistingData = 0
	Begin
		Set @LogMessage = 'Call DeletePeptidesForJobAndResetToNew for Job ' + @jobStr
		if @LogLevel >= 2
			execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

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
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

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
		execute PostLogEntry 'Error', @message, 'LoadSequestPeptidesBulk'
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

	If @ResultToSeqMapCountLoaded > 0
	Begin
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
			execute PostLogEntry 'Error', @message, 'LoadSequestPeptidesBulk'
			Set @message = ''
		End
	End

	-----------------------------------------------
	-- Make sure all peptides in #Tmp_Peptide_Import have
	-- a reference defined; if any do not, give them
	-- a bogus reference name and post an entry to the log
	-----------------------------------------------
	UPDATE #Tmp_Peptide_Import
	SET Reference = 'xx_Unknown_Protein_Reference_xx'
	WHERE Reference IS NULL
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myRowCount > 0
	Begin
		Set @message = 'Newly imported peptides found with Null reference values for job ' + @jobStr + ' (' + convert(varchar(11), @myRowCount) + ' peptides)'
		execute PostLogEntry 'Error', @message, 'LoadSequestPeptidesBulk'
		Set @message = ''
	End

	-----------------------------------------------
	-- Check for proteins with long names
	-- MTS can handle protein names up to 255 characters long
	--  but SEQUEST will truncate protein names over 34 or 40 characters
	--  long (depending on the version) so we're checking here to notify
	--  the DMS admins if long protein names are encountered
	-----------------------------------------------
	If @ResultToSeqMapCountLoaded > 0
	Begin
		SELECT @LongProteinNameCount = COUNT(Distinct Reference)
		FROM #Tmp_Peptide_SeqToProteinMap
		WHERE Len(Reference) > 34 AND
			  NOT (	Reference LIKE 'reversed[_]%' OR	-- MTS reversed proteins
					Reference LIKE 'scrambled[_]%' OR	-- MTS scrambled proteins
					Reference LIKE '%[:]reversed' OR	-- X!Tandem decoy proteins
					Reference LIKE 'xxx.%'				-- Inspect reversed/scrambled proteins
				  )
	End
	Else
	Begin
		SELECT @LongProteinNameCount = COUNT(Distinct Reference)
		FROM #Tmp_Peptide_Import
		WHERE Len(Reference) > 34 AND
			  NOT (	Reference LIKE 'reversed[_]%' OR	-- MTS reversed proteins
					Reference LIKE 'scrambled[_]%' OR	-- MTS scrambled proteins
					Reference LIKE '%[:]reversed' OR	-- X!Tandem decoy proteins
					Reference LIKE 'xxx.%'				-- Inspect reversed/scrambled proteins
				  )
	End
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @LongProteinNameCount > 0
	Begin
		Set @message = 'Newly imported peptides found with protein names longer than 34 characters for job ' + @jobStr + ' (' + convert(varchar(11), @LongProteinNameCount) + ' distinct proteins)'
		execute PostLogEntry 'Error', @message, 'LoadSequestPeptidesBulk'
		Set @message = ''
	End

	Set @LogMessage = 'Data verification complete'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

	-----------------------------------------------
	-- Generate a temporary table listing the minimum Result_ID value
	--  for each unique combination of Scan_Number, Charge_State, MH, Peptide
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
	If @ResultToSeqMapCountLoaded > 0
	Begin
		INSERT INTO #Tmp_Unique_Records (Result_ID, Scan_Number, Number_Of_Scans, Charge_State, MH, Peptide)
		SELECT MIN(TPI.Result_ID), TPI.Scan_Number, TPI.Number_Of_Scans, TPI.Charge_State, TPI.MH, TPI.Peptide
		FROM #Tmp_Peptide_Import TPI INNER JOIN
			 #Tmp_Peptide_ResultToSeqMap RTSM ON TPI.Result_ID = RTSM.Result_ID
		GROUP BY TPI.Scan_Number, TPI.Number_Of_Scans, TPI.Charge_State, TPI.MH, TPI.Peptide
		ORDER BY MAX(TPI.XCorr) DESC, TPI.Scan_Number, TPI.Peptide
	End
	Else
	Begin
		INSERT INTO #Tmp_Unique_Records (Result_ID, Scan_Number, Number_Of_Scans, Charge_State, MH, Peptide)
		SELECT MIN(Result_ID), Scan_Number, Number_Of_Scans, Charge_State, MH, Peptide
		FROM #Tmp_Peptide_Import
		GROUP BY Scan_Number, Number_Of_Scans, Charge_State, MH, Peptide
		ORDER BY MAX(XCorr) DESC, Scan_Number, Peptide
	End
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
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'


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
	declare @numAddedSeqScores int
	declare @numAddedDiscScores int

	Set @LogMessage = 'Begin Transaction'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

	declare @transName varchar(32)
	set @transName = 'LoadSequestPeptidesBulk'

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
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'


			If @CreateDebugTables = 1
			Begin
				SELECT *
				INTO T_Tmp_Unique_Records
				FROM #Tmp_Unique_Records
			End

			-----------------------------------------------
			-- Add new proteins to T_Proteins
			-----------------------------------------------
			Set @CurrentLocation = 'Add new proteins to T_Proteins'

			If @ResultToSeqMapCountLoaded > 0
			Begin
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
			End
			Else
			Begin
				INSERT INTO T_Proteins (Reference)
				SELECT LookupQ.Reference
				FROM (	SELECT TPI.Reference
						FROM #Tmp_Peptide_Import TPI
						GROUP BY TPI.Reference
					) LookupQ LEFT OUTER JOIN
					T_Proteins ON LookupQ.Reference = T_Proteins.Reference
				WHERE T_Proteins.Ref_ID IS NULL
				ORDER BY LookupQ.Reference
			End
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
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'


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
				@Job AS Job,
				TPI.Scan_Number,
				TPI.Number_Of_Scans,
				TPI.Charge_State,
				TPI.MH,
				TPI.Multiple_Protein_Count,
				TPI.Peptide,
				TPI.RankXC,
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
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

			SET IDENTITY_INSERT T_Peptides OFF


			-----------------------------------------------
			-- Copy selected contents of #Tmp_Peptide_Import
			-- into T_Score_Discriminant
			-- Note that if @SynFileVersion is '2011', then MScore=10 and PassFilt=1 for all peptides
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Populate T_Score_Discriminant using #Tmp_Peptide_Import'

			Declare @S varchar(2048) = ''
			Set @S = 'INSERT INTO T_Score_Discriminant (Peptide_ID, MScore, PassFilt)'

			If @SynFileVersion = '2005'
				Set @S = @S + ' SELECT UR.Peptide_ID_New, TPI.MScore, TPI.PassFilt '

			If @SynFileVersion = '2011'
				Set @S = @S + ' SELECT UR.Peptide_ID_New, 10 AS MScore, 1 AS PassFilt '

			Set @S = @S + ' FROM #Tmp_Peptide_Import TPI INNER JOIN'
			Set @S = @S +     '  #Tmp_Unique_Records UR ON TPI.Result_ID = UR.Result_ID'
			Set @S = @S + ' ORDER BY UR.Peptide_ID_New'

			Exec (@S)
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
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'


			-----------------------------------------------
			-- Copy selected contents of #Tmp_Peptide_Import
			-- into T_Score_Sequest
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Populate T_Score_Sequest using #Tmp_Peptide_Import'

			INSERT INTO T_Score_Sequest
				(Peptide_ID, XCorr, DeltaCn, DeltaCn2,
				Sp, RankSp, RankXc, DelM, XcRatio)
			SELECT
				UR.Peptide_ID_New,
				TPI.XCorr,
				TPI.DeltaCn,
				TPI.DeltaCn2,
				TPI.Sp,
				TPI.RankSp,
				TPI.RankXc,
				TPI.DelM,
				TPI.RatioXc
			FROM #Tmp_Peptide_Import TPI INNER JOIN
				#Tmp_Unique_Records UR ON TPI.Result_ID = UR.Result_ID
			ORDER BY UR.Peptide_ID_New
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				rollback transaction @transName
				set @message = 'Error inserting into T_Score_Sequest for job ' + @jobStr
				goto Done
			end
			Set @numAddedSeqScores = @myRowCount

			Set @LogMessage = 'Populated T_Score_Sequest with ' + Convert(varchar(12), @myRowCount) + ' rows'
			if @LogLevel >= 2
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'


			-----------------------------------------------
			-- Copy selected contents of #Tmp_Peptide_Import and
			--  #Tmp_Peptide_SeqToProteinMap into T_Peptide_to_Protein_Map table;
			-- We shouldn't have to use the Group By when inserting, but if the synopsis file
			--  has multiple entries for the same combination of Scan_Number, Number_of_Scans,
			--  Charge_State, MH, and Peptide pointing to the same Reference, then this
			--  will cause a primary key constraint error.
			-----------------------------------------------
			--
			If @ResultToSeqMapCountLoaded > 0
			Begin
				Set @CurrentLocation = 'Populate T_Peptide_to_Protein_Map using #Tmp_Peptide_Import and #Tmp_Peptide_ResultToSeqMap'

				INSERT INTO T_Peptide_to_Protein_Map (Peptide_ID, Ref_ID, Cleavage_State, Terminus_State)
				SELECT	UR.Peptide_ID_New, P.Ref_ID,
						MAX(IsNull(STPM.Cleavage_State, 0)),
						MAX(IsNull(STPM.Terminus_State, 0))
				FROM #Tmp_Unique_Records UR INNER JOIN
					#Tmp_Peptide_Import TPI ON
						UR.Scan_Number = TPI.Scan_Number AND
						UR.Number_Of_Scans = TPI.Number_Of_Scans AND
						UR.Charge_State = TPI.Charge_State AND
						UR.MH = TPI.MH AND
						UR.Peptide = TPI.Peptide INNER JOIN
					#Tmp_Peptide_ResultToSeqMap RTSM ON TPI.Result_ID = RTSM.Result_ID INNER JOIN
					#Tmp_Peptide_SeqInfo PSI ON RTSM.Seq_ID_Local = PSI.Seq_ID_Local INNER JOIN
					#Tmp_Peptide_SeqToProteinMap STPM ON PSI.Seq_ID_Local = STPM.Seq_ID_Local INNER JOIN
					T_Proteins P ON STPM.Reference = P.Reference
				GROUP BY UR.Peptide_ID_New, P.Ref_ID
				ORDER BY UR.Peptide_ID_New
			End
			Else
			Begin
				Set @CurrentLocation = 'Populate T_Peptide_to_Protein_Map using #Tmp_Peptide_Import'

				INSERT INTO T_Peptide_to_Protein_Map (Peptide_ID, Ref_ID, Cleavage_State, Terminus_State)
				SELECT 	UR.Peptide_ID_New, P.Ref_ID,
						MAX(IsNull(PCS.Cleavage_State, 0)),
			   			MAX(IsNull(PCS.Terminus_State, 0))
				FROM #Tmp_Unique_Records UR INNER JOIN
					#Tmp_Peptide_Import TPI ON
						UR.Scan_Number = TPI.Scan_Number AND
						UR.Number_Of_Scans = TPI.Number_Of_Scans AND
						UR.Charge_State = TPI.Charge_State AND
						UR.MH = TPI.MH AND
						UR.Peptide = TPI.Peptide INNER JOIN
					#Tmp_Peptide_Cleavage_State PCS ON UR.Result_ID = PCS.Result_ID INNER JOIN
					T_Proteins P ON TPI.Reference = P.Reference
				GROUP BY UR.Peptide_ID_New, P.Ref_ID
				ORDER BY UR.Peptide_ID_New
			End
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
			If @ResultToSeqMapCountLoaded > 0
				Set @LogMessage = @LogMessage + ' (used the SeqInfo file data)'
			Else
				Set @LogMessage = @LogMessage + ' (SeqInfo file data is not available))'

			if @LogLevel >= 2
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'


			-----------------------------------------------
			-- Verify that all inserts have same number of rows
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Verify counts'

			Set @numAddedPeptides = IsNull(@numAddedPeptides, 0)
			Set @numAddedSeqScores = IsNull(@numAddedSeqScores, 0)
			Set @numAddedDiscScores = IsNull(@numAddedDiscScores, 0)

			if @numAddedPeptides <> @numAddedSeqScores
			begin
				rollback transaction @transName
				set @message = 'Error in rowcounts for @numAddedPeptides vs @numAddedSeqScores for job ' + @jobStr + '; ' + Convert(varchar(12), @numAddedPeptides) + ' <> ' + Convert(varchar(12), @numAddedSeqScores)
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
			          P.Number_Of_Scans = TPI.Number_Of_Scans AND
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

			If @UnmatchedRowCount > 0
			Begin
				-- Try to udpate #Tmp_Unique_Records again, but this time update the peptides to remove *, #, @, etc.
				--
				UPDATE #Tmp_Unique_Records
				SET Peptide_ID_New = P.Peptide_ID
				FROM #Tmp_Peptide_Import TPI
				     INNER JOIN #Tmp_Unique_Records UR
				       ON TPI.Result_ID = UR.Result_ID
				     INNER JOIN T_Peptides P
				       ON P.Job = @Job AND
				          P.Scan_Number = TPI.Scan_Number AND
				          P.Number_Of_Scans = TPI.Number_Of_Scans AND
				          P.Charge_State = TPI.Charge_State AND
				          dbo.udfCleanSequence(P.Peptide) = dbo.udfCleanSequence(TPI.Peptide)
				WHERE UR.Peptide_ID_New IS NULL

				SELECT @numLoaded = COUNT(*),
				       @UnmatchedRowCount = SUM(CASE WHEN Peptide_ID_New IS NULL THEN 1 ELSE 0 END)
				FROM #Tmp_Unique_Records

			End

			If @CreateDebugTables = 1
			Begin
				SELECT *
				INTO T_Tmp_Unique_Records
				FROM #Tmp_Unique_Records
			End


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
						exec PostLogEntry 'Error', @LogMessage, 'LoadSequestPeptidesBulk'
					End
					Else
					Begin
						exec PostLogEntry 'Warning', @LogMessage, 'LoadSequestPeptidesBulk'
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
			    RankHit = TPI.RankXC,
			    DelM_PPM = TPI.DelM_PPM
			FROM #Tmp_Peptide_Import TPI
			     INNER JOIN #Tmp_Unique_Records UR
			       ON TPI.Result_ID = UR.Result_ID
			     INNER JOIN T_Peptides Pep
			       ON Pep.Peptide_ID = UR.Peptide_ID_New
			WHERE IsNull(Pep.MH, -1) <> TPI.MH OR
			      IsNull(Pep.RankHit, 0) <> TPI.RankXC OR
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
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

			-----------------------------------------------
			-- Update T_Score_Discriminant
			-- Note that if @SynFileVersion is '2011', then MScore=10 and PassFilt=1 for all peptides
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Update T_Score_Discriminant using #Tmp_Peptide_Import'

			If @SynFileVersion = '2005'
			Begin
				UPDATE T_Score_Discriminant
				SET MScore = TPI.MScore,
				    PassFilt = TPI.PassFilt
				FROM #Tmp_Peptide_Import TPI
				     INNER JOIN #Tmp_Unique_Records UR
				       ON TPI.Result_ID = UR.Result_ID
				   INNER JOIN T_Score_Discriminant SD
				       ON SD.Peptide_ID = UR.Peptide_ID_New
				WHERE IsNull(SD.MScore, -1) <> TPI.MScore OR
				      IsNull(SD.PassFilt, -1) <> TPI.PassFilt
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
			End

			If @SynFileVersion = '2011'
			Begin
				UPDATE T_Score_Discriminant
				SET MScore = 10,
				    PassFilt = 1
				FROM T_Score_Discriminant SD
				     INNER JOIN T_Peptides Pep
				       ON SD.Peptide_ID = Pep.Peptide_ID
				WHERE Pep.Job = @job AND
				      (IsNull(SD.MScore, -1) <> 10 OR
				       IsNull(SD.PassFilt, -1) <> 1)
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
			End

			if @myError <> 0
			begin
				rollback transaction @transName
				set @message = 'Error updating T_Score_Discriminant for job ' + @jobStr
				goto Done
			end
			Set @numAddedDiscScores = @myRowCount

			Set @LogMessage = 'Update ' + Convert(varchar(12), @myRowCount) + ' rows in T_Score_Discriminant'
			if @LogLevel >= 2
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'


			-----------------------------------------------
			-- Update T_Score_Sequest
			-----------------------------------------------
			--
			Set @CurrentLocation = 'Update T_Score_Sequest using #Tmp_Peptide_Import'

			UPDATE T_Score_Sequest
			SET XCorr = TPI.XCorr,
			    DeltaCn = TPI.DeltaCn,
			    DeltaCn2 = TPI.DeltaCn2,
			    Sp = TPI.Sp,
			    RankSp = TPI.RankSp,
			    RankXc = TPI.RankXc,
			    DelM = TPI.DelM,
			    XcRatio = TPI.RatioXc
			FROM #Tmp_Peptide_Import TPI
			    INNER JOIN #Tmp_Unique_Records UR
			       ON TPI.Result_ID = UR.Result_ID
			     INNER JOIN T_Peptides Pep
			       ON Pep.Peptide_ID = UR.Peptide_ID_New
			    INNER JOIN T_Score_Sequest SS
			       ON Pep.Peptide_ID = SS.Peptide_ID
			WHERE IsNull(SS.XCorr, -1) <> TPI.XCorr OR
			      IsNull(SS.DeltaCn, -1) <> TPI.DeltaCn OR
			      IsNull(SS.DeltaCn2, -1) <> TPI.DeltaCn2 OR
			      IsNull(SS.Sp, -1) <> TPI.Sp OR
			      IsNull(SS.RankSp, -1) <> TPI.RankSp OR
			      IsNull(SS.RankXc, -1) <> TPI.RankXc OR
			      IsNull(SS.DelM, -9999) <> TPI.DelM OR
			      IsNull(SS.XcRatio, -1) <> TPI.RatioXc
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				rollback transaction @transName
				set @message = 'Error updating T_Score_Sequest for job ' + @jobStr
				goto Done
			end
			Set @numAddedSeqScores = @myRowCount

			Set @LogMessage = 'Updated ' + Convert(varchar(12), @myRowCount) + ' rows in T_Score_Sequest'
			if @LogLevel >= 2
				execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'


			-----------------------------------------------
			-- Change XCorr to -XCorr for peptides that are in T_Score_Sequest yet are not in #Tmp_Peptide_Import
			-- This will commonly be the case if the data was loosely filtered when it was initially loaded but was
			-- filtered out of #Tmp_Peptide_Import on this load
			-----------------------------------------------
			--
			UPDATE T_Score_Sequest
			SET XCorr = -ABS(SS.XCorr)
			FROM T_Peptides Pep
			     INNER JOIN T_Score_Sequest SS
			       ON Pep.Peptide_ID = SS.Peptide_ID
			     LEFT OUTER JOIN #Tmp_Unique_Records UR
			       ON Pep.Peptide_ID = UR.Peptide_ID_New
			WHERE Pep.Job = @Job AND
			      SS.XCorr > 0 AND
			      UR.Peptide_ID_New IS NULL
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			If @myRowCount > 0
			Begin
				Set @LogMessage = 'Changed XCorr to a negative value for ' + Convert(varchar(12), @myRowCount) + ' entries for job ' + @jobStr + ' since the peptides no longer pass filters'
				execute PostLogEntry 'Warning', @LogMessage, 'LoadSequestPeptidesBulk'
			End

			-----------------------------------------------
			-- Note: we do not update T_Proteins or T_Peptide_to_Protein_Map
			-----------------------------------------------

			SELECT @numLoaded = COUNT(*)
			FROM #Tmp_Unique_Records

		End -- </a2>

		-----------------------------------------------
		-- Commit changes to T_Peptides, T_Score_Sequest, etc. if we made it this far
		-----------------------------------------------
		--
		Set @CurrentLocation = 'Commit changes'

		commit transaction @transName

		Set @LogMessage = 'Transaction committed'
		if @LogLevel >= 2
		Begin
			execute PostLogEntryAddToCache 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'
			execute PostLogEntryFlushCache
		End

	End Try
	Begin Catch
		if @@TranCount > 0
			rollback transaction

		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'LoadSequestPeptidesBulk')
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
	          TPI2.Number_Of_Scans = TPI.Number_Of_Scans AND
	          TPI2.Charge_State = TPI.Charge_State AND
	          TPI2.XCorr = TPI.XCorr AND
	          TPI2.DeltaCn = TPI.DeltaCn AND
	          TPI2.Peptide = TPI.Peptide AND
	          TPI2.Result_ID <> TPI.Result_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


	Set @LogMessage = 'Populated #Tmp_Peptide_Import_MatchedEntries with ' + Convert(varchar(12), @myRowCount) + ' rows'
	if @LogLevel >= 2
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

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
			execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'
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
		execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'


	-----------------------------------------------
	-- If @ResultToSeqMapCountLoaded > 0, then call LoadSeqInfoAndModsPart2
	--  to populate the Candidate Sequence tables
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
			execute PostLogEntry 'Progress', @LogMessage, 'LoadSequestPeptidesBulk'

	End

Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[LoadSequestPeptidesBulk] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[LoadSequestPeptidesBulk] TO [MTS_DB_Lite] AS [dbo]
GO
