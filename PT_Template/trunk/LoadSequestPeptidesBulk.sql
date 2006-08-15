/****** Object:  StoredProcedure [dbo].[LoadSequestPeptidesBulk] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.LoadSequestPeptidesBulk
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
**	Parameters:
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
**
*****************************************************/
(
	@PeptideSynFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn.txt',
	@PeptideResultToSeqMapFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn_ResultToSeqMap.txt',
	@PeptideSeqInfoFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn_SeqInfo.txt',
	@PeptideSeqModDetailsFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn_ModDetails.txt',
	@PeptideSeqToProteinMapFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn_SeqToProteinMap.txt',
	@PeptideProphetResultsFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_syn_PepProphet.txt',
	@Job int,
	@FilterSetID int,
	@LineCountToSkip int=0,
	@numLoaded int=0 output,
	@numSkipped int=0 output,
	@SeqCandidateFilesFound tinyint=0 output,
	@PepProphetFileFound tinyint=0 output,
	@message varchar(512)='' output
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
	set @message = ''

	declare @jobStr varchar(12)
	set @jobStr = convert(varchar(12), @Job)

	declare @Sql varchar(2048)
	declare @UnfilteredCountLoaded int
	set @UnfilteredCountLoaded = 0

	declare @RowCountTotal int
	declare @RowCountNull int
	declare @RowCountNullCharge5OrLess int
	declare @MessageType varchar(32)

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
		RankXc  	Rank based CrossCorr
		DelM    	Error parent ion
		XcRatio 	Ratio Xcorr(n)/Xcorr(top)
		PassFilt  	Filter(0=fail, other=pass)
		MScore  	Fragmentation Score
		NTT	  		Number of tryptic termini, aka Cleavage_State (NTT does not treat tryptic terminii correctly)

	***/
	CREATE TABLE #Tmp_Peptide_Import (
		Result_ID int NOT NULL ,
		Scan_Number int NULL ,
		Number_Of_Scans smallint NULL ,
		Charge_State smallint NULL ,
		MH float NULL ,
		XCorr real NULL ,
		DeltaCn real NULL ,
		Sp float NULL ,
		Reference varchar (255) NULL ,
		Multiple_Protein_Count int NULL ,
		Peptide varchar (850) NULL,
		DeltaCn2 real NULL ,
		RankSp real NULL ,
		RankXc real NULL ,
		DelM float NULL ,
		RatioXc real NULL ,
		PassFilt int NULL,
		MScore real NULL,
		Cleavage_State smallint NULL
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #Tmp_Peptide_Import for job ' + @jobStr
		goto Done
	end
	
	CREATE CLUSTERED INDEX IX_Tmp_Peptide_Import_Result_ID ON #Tmp_Peptide_Import (Result_ID)
	CREATE INDEX IX_Tmp_Peptide_Import_Scan_Number ON #Tmp_Peptide_Import (Scan_Number)

	-----------------------------------------------
	-- Create a table for holding re-computed cleavage
	-- and terminus state values
	-----------------------------------------------
	CREATE TABLE #Tmp_Peptide_Cleavage_State (
		Result_ID int NOT NULL ,
		Cleavage_State tinyint NULL ,
		Terminus_State tinyint NULL
	)
	
	CREATE CLUSTERED INDEX IX_Tmp_Peptide_Cleavage_State_Result_ID ON #Tmp_Peptide_Cleavage_State (Result_ID)
		
	
	-----------------------------------------------
	-- Also create a table for holding flags of whether or not
	-- the peptides pass the import filter
	-----------------------------------------------
	CREATE TABLE #Tmp_Peptide_Filter_Flags (
		Result_ID int NOT NULL,
		Valid tinyint NOT NULL
	)

	CREATE CLUSTERED INDEX IX_Tmp_Peptide_Filter_Flags_Result_ID ON #Tmp_Peptide_Filter_Flags (Result_ID)

	-----------------------------------------------
	-- Bulk load contents of synopsis file into temporary table
	-----------------------------------------------
	--
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

	-----------------------------------------------
	-- Populate @UnfilteredCountLoaded; this will be compared against
	-- the ResultToSeqMap count loaded to confirm that they match
	-----------------------------------------------
	SELECT @UnfilteredCountLoaded = Count(*)
	FROM #Tmp_Peptide_Import
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


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

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_Peptide_SeqToProteinMap]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_Peptide_SeqToProteinMap]

		if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#Tmp_PepProphet_Results]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#Tmp_PepProphet_Results]
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

	CREATE CLUSTERED INDEX IX_Tmp_Peptide_ResultToSeqMap_Result_ID ON #Tmp_Peptide_ResultToSeqMap (Result_ID)


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

	CREATE CLUSTERED INDEX IX_Tmp_Peptide_SeqInfo_Seq_ID ON #Tmp_Peptide_SeqInfo (Seq_ID_Local)
	

	-- Table for contents of the ModDetails file
	--
	CREATE TABLE #Tmp_Peptide_ModDetails (
		Seq_ID_Local int NOT NULL ,
		Mass_Correction_Tag varchar(128) NOT NULL ,			-- Note: The mass correction tags are limited to 8 characters when storing in T_Seq_Candidate_ModDetails
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

	CREATE CLUSTERED INDEX IX_Tmp_Peptide_ModDetails_Seq_ID ON #Tmp_Peptide_ModDetails (Seq_ID_Local)


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

	CREATE CLUSTERED INDEX IX_Tmp_Peptide_SeqToProteinMap_Seq_ID ON #Tmp_Peptide_SeqToProteinMap (Seq_ID_Local)


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
	-- Call LoadPeptideProphetResultsOneJob to load
	-- the PepProphet results file (if it exists)
	-----------------------------------------------
	Declare @PeptideProphetCountLoaded int
	Set @PeptideProphetCountLoaded = 0

	exec @myError = LoadPeptideProphetResultsOneJob @job, @PeptideProphetResultsFilePath, @PeptideProphetCountLoaded output, @message output

	if @myError <> 0
	Begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling LoadPeptideProphetResultsOneJob for job ' + @jobStr
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
						@message output

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
			Set @myError = 50002
			Set @message = 'Row count in the _ResultToSeqMap.txt file does not match the expected unique row count determined for the Sequest _syn.txt file for job ' + @jobStr + ' (' + Convert(varchar(12), @ResultToSeqMapCountLoaded) + ' vs. ' + Convert(varchar(12), @ExpectedResultToSeqMapCount) + ')'
			Goto Done
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

	CREATE CLUSTERED INDEX IX_Tmp_Unfiltered_Unique_Records_Result_ID ON #Tmp_Unfiltered_Unique_Records (Result_ID)
	CREATE INDEX IX_Tmp_Unfiltered_Unique_Records_MH ON #Tmp_Unfiltered_Unique_Records (MH)
	CREATE INDEX IX_Tmp_Unfiltered_Unique_Records_Scan_Number ON #Tmp_Unfiltered_Unique_Records (Scan_Number)
	
	
	-----------------------------------------------
	-- Populate #Tmp_Unfiltered_Unique_Records
	-----------------------------------------------
	--
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
			@XTandemLogEValueThreshold real				-- Not used in this SP

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
									@XTandemLogEValueComparison OUTPUT, @XTandemLogEValueThreshold OUTPUT
	
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
	INSERT INTO #Tmp_Peptide_Filter_Flags (Result_ID, Valid)
	SELECT Result_ID, 0
	FROM #Tmp_Peptide_Import
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


	-----------------------------------------------
	-- Mark peptides that pass the thresholds
	-----------------------------------------------

	While @CriteriaGroupMatch > 0
	Begin
		-- Construct the Sql Update Query
		--
		Set @Sql = ''
		Set @Sql = @Sql + ' UPDATE #Tmp_Peptide_Filter_Flags'
		Set @Sql = @Sql + ' SET Valid = 1'
		Set @Sql = @Sql + ' FROM #Tmp_Peptide_Filter_Flags TFF INNER JOIN'
		Set @Sql = @Sql +      ' #Tmp_Peptide_Import TPI ON TFF.Result_ID = TPI.Result_ID INNER JOIN'
		Set @Sql = @Sql +      ' #Tmp_Peptide_Cleavage_State PCS ON TPI.Result_ID = PCS.Result_ID'
		Set @Sql = @Sql + ' WHERE '
		Set @Sql = @Sql +	' PCS.Cleavage_State ' + @CleavageStateComparison + Convert(varchar(6), @CleavageStateThreshold) + ' AND '
		Set @Sql = @Sql +	' PCS.Terminus_State ' + @TerminusStateComparison + Convert(varchar(6), @TerminusStateThreshold) + ' AND '
		Set @Sql = @Sql +	' TPI.Charge_State ' + @ChargeStateComparison + Convert(varchar(6), @ChargeStateThreshold) + ' AND '
		Set @Sql = @Sql +	' TPI.XCorr ' + @HighNormalizedScoreComparison +  Convert(varchar(11), @HighNormalizedScoreThreshold) + ' AND '
		Set @Sql = @Sql +	' TPI.MH ' + @MassComparison + Convert(varchar(11), @MassThreshold) + ' AND '
		Set @Sql = @Sql +	' TPI.DeltaCn ' + @DeltaCnComparison + Convert(varchar(11), @DeltaCnThreshold) + ' AND '
		Set @Sql = @Sql +   ' TPI.PassFilt ' + @DiscriminantInitialFilterComparison + Convert(varchar(11), @DiscriminantInitialFilterThreshold)

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
										@XTandemLogEValueComparison OUTPUT, @XTandemLogEValueThreshold OUTPUT
		If @myError <> 0
		Begin
			Set @Message = 'Error retrieving next entry from GetThresholdsForFilterSet in LoadSequestPeptidesBulk'
			Goto Done
		End

	End -- While

	
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
	

	-----------------------------------------------
	-- Possibly copy the data from #Tmp_Peptide_Import into #Tmp_Peptide_Import_Unfiltered
	-----------------------------------------------
	If @UsingPhysicalTempTables = 1
		SELECT *
		INTO #Tmp_Peptide_Import_Unfiltered
		FROM #Tmp_Peptide_Import
		ORDER BY Result_ID


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


	-----------------------------------------------
	-- Delete any existing results in T_Peptides, T_Score_Sequest
	-- T_Score_Discriminant, etc. for this analysis job
	-----------------------------------------------
	Exec @myError = DeletePeptidesForJobAndResetToNew @job, @ResetStateToNew=0, @DeleteUnusedSequences=0, @DropAndAddConstraints=0
	--
	if @myError <> 0
	begin
		set @message = 'Problem deleting existing peptide entries for job ' + @jobStr
		Set @myError = 50004
		goto Done
	end


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

	CREATE CLUSTERED INDEX IX_Tmp_Unique_Records_Result_ID ON #Tmp_Unique_Records (Result_ID)
	CREATE INDEX IX_Tmp_Unique_Records_MH ON #Tmp_Unique_Records (MH)
	CREATE INDEX IX_Tmp_Unique_Records_Scan_Number ON #Tmp_Unique_Records (Scan_Number)
	
	
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


	---------------------------------------------------
	--  Start a transaction
	---------------------------------------------------
	
	declare @numAddedPeptides int
	declare @numAddedSeqScores int
	declare @numAddedDiscScores int
	declare @numAddedPepProphetScores int
	
	declare @transName varchar(32)
	set @transName = 'LoadSequestPeptidesBulk'
	begin transaction @transName

	-----------------------------------------------
	-- Get base value for peptide ID calculation
	-- Note that @MaxPeptideID will get added to #Tmp_Unique_Records.Peptide_ID_Base, 
	--  which will always start at 1
	-----------------------------------------------
	--
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

	-----------------------------------------------
	-- Add new proteins to T_Proteins
	-----------------------------------------------
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

	-----------------------------------------------
	-- Copy selected contents of #Tmp_Peptide_Import
	-- into T_Peptides
	-----------------------------------------------
	--
	SET IDENTITY_INSERT T_Peptides ON 
	--
	INSERT INTO T_Peptides
	(
		Peptide_ID, 
		Analysis_ID, 
		Scan_Number, 
		Number_Of_Scans, 
		Charge_State, 
		MH, 
		Multiple_ORF, 
		Peptide
	)
	SELECT
		UR.Peptide_ID_New,
		@Job,					-- Job, aka Analysis_ID
		TPI.Scan_Number,
		TPI.Number_Of_Scans,
		TPI.Charge_State,
		TPI.MH,
		TPI.Multiple_Protein_Count,
		TPI.Peptide
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

	SET IDENTITY_INSERT T_Peptides OFF 


	-----------------------------------------------
	-- Copy selected contents of #Tmp_Peptide_Import
	-- into T_Score_Discriminant
	-----------------------------------------------
	--
	INSERT INTO T_Score_Discriminant
		(Peptide_ID, MScore, PassFilt)
	SELECT
		UR.Peptide_ID_New, TPI.MScore, TPI.PassFilt
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


	If @PeptideProphetCountLoaded > 0
	Begin -- <a>
		Set @PepProphetFileFound = 1

		-----------------------------------------------
		-- Copy selected contents of #Tmp_PepProphet_Results
		-- into T_Score_Discriminant
		-----------------------------------------------
		--
		UPDATE T_Score_Discriminant
		SET Peptide_Prophet_FScore = PPR.FScore,
			Peptide_Prophet_Probability = PPR.Probability
		FROM T_Score_Discriminant SD INNER JOIN 
			 #Tmp_Unique_Records UR ON SD.Peptide_ID = UR.Peptide_ID_New INNER JOIN
			 #Tmp_Peptide_Import TPI ON UR.Result_ID = TPI.Result_ID INNER JOIN
			 #Tmp_PepProphet_Results PPR ON TPI.Result_ID = PPR.Result_ID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @myError <> 0
		begin
			rollback transaction @transName
			set @message = 'Error updating T_Score_Discriminant with Peptide Prophet results for job ' + @jobStr
			goto Done
		end
		Set @numAddedPepProphetScores = @myRowCount

		If @numAddedPepProphetScores < @numAddedDiscScores
		Begin -- <b>
			-----------------------------------------------
			-- If a peptide is mapped to multiple proteins in #Tmp_Peptide_Import, then
			--  #Tmp_PepProphet_Results may only contain the results for one of the entries
			-- The following query helps account for this by linking #Tmp_Peptide_Import to itself,
			--  along with linking it to #Tmp_Unique_Records and #Tmp_PepProphet_Results
			-- 
			-- This situation should only be true for a handful of jobs analyzed in July 2006
			--  therefore, we'll post a warning entry to the log if this situation is encountered
			--
			-- Note, however, that Peptide Prophet values are not computed for charge states of 6 or higher,
			-- so data with charge state 6 or higher will not have values present in #Tmp_PepProphet_Results
			-----------------------------------------------
	
			UPDATE T_Score_Discriminant
			SET Peptide_Prophet_FScore = PPR.FScore,
				Peptide_Prophet_Probability = PPR.Probability
			FROM T_Score_Discriminant SD INNER JOIN
				 #Tmp_Unique_Records UR ON SD.Peptide_ID = UR.Peptide_ID_New INNER JOIN
				 #Tmp_Peptide_Import TPI2 ON UR.Result_ID = TPI2.Result_ID INNER JOIN
				 #Tmp_Peptide_Import TPI ON 
					TPI2.Scan_Number = TPI.Scan_Number AND 
					TPI2.Number_Of_Scans = TPI.Number_Of_Scans AND 
					TPI2.Charge_State = TPI.Charge_State AND 
					TPI2.XCorr = TPI.XCorr AND TPI2.DeltaCn = TPI.DeltaCn AND 
					TPI2.Peptide = TPI.Peptide AND 
					TPI2.Result_ID <> TPI.Result_ID INNER JOIN
				 #Tmp_PepProphet_Results PPR ON TPI.Result_ID = PPR.Result_ID
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				rollback transaction @transName
				set @message = 'Error updating T_Score_Discriminant with Peptide Prophet results for job ' + @jobStr + ' (Query #2)'
				goto Done
			end
			Set @numAddedPepProphetScores = @numAddedPepProphetScores + @myRowCount


			SELECT	@RowCountTotal = COUNT(*),
					@RowCountNull = SUM(CASE WHEN SD.Peptide_Prophet_FScore IS NULL OR 
												  SD.Peptide_Prophet_Probability IS NULL 
										THEN 1 ELSE 0 END),
					@RowCountNullCharge5OrLess = SUM(CASE WHEN UR.Charge_State <= 5 AND (
														SD.Peptide_Prophet_FScore IS NULL OR 
														SD.Peptide_Prophet_Probability IS NULL)
										THEN 1 ELSE 0 END)
			FROM T_Score_Discriminant SD INNER JOIN
				 #Tmp_Unique_Records UR ON SD.Peptide_ID = UR.Peptide_ID_New


			If @RowCountNull > 0
			Begin -- <c>
				set @message = 'Job ' + @jobStr + ' has ' + Convert(varchar(12), @RowCountNull) + ' out of ' + Convert(varchar(12), @RowCountTotal) + ' rows in T_Score_Discriminant with null peptide prophet FScore or Probability values'

				If @RowCountNullCharge5OrLess = 0
				Begin
					set @message = @message + '; however, all have charge state 6+ or higher'
					set @MessageType = 'Warning'
				End
				Else
				Begin
					set @message = @message + '; furthermore, ' + Convert(varchar(12), @RowCountNullCharge5OrLess) + ' of the rows have charge state 5+ or less'
					set @MessageType = 'Error'
				End

				execute PostLogEntry @MessageType, @message, 'LoadSequestPeptidesBulk'
				Set @message = ''
			End -- </c>
		End -- </b>
	End -- </a>
	Else
	Begin
		Set @PeptideProphetCountLoaded = 0
		Set @numAddedPepProphetScores = 0
	End


	-----------------------------------------------
	-- Copy selected contents of #Tmp_Peptide_Import
	-- into T_Score_Sequest
	-----------------------------------------------
	--
	INSERT INTO T_Score_Sequest
		(Peptide_ID, XCorr, DeltaCn, DeltaCn2, Sp, RankSp, RankXc, DelM, XcRatio)
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


	-----------------------------------------------
	-- Verify that all inserts have same number of rows
	-----------------------------------------------
	--
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


	-----------------------------------------------
	-- Commit changes to T_Peptides, T_Score_Sequest, etc. if we made it this far
	-----------------------------------------------
	--
	commit transaction @transName


	-----------------------------------------------
	-- If @ResultToSeqMapCountLoaded > 0, then call LoadSeqInfoAndModsPart2 
	--  to populate the Candidate Sequence tables
	-- Note that LoadSeqInfoAndModsPart2 uses tables:
	--  #Tmp_Peptide_Import
	--  #Tmp_Unique_Records
	--  #Tmp_Peptide_ResultToSeqMap
	--  #Tmp_Peptide_SeqInfo
	--  #Tmp_Peptide_ModDetails
	-----------------------------------------------
	--
	If @ResultToSeqMapCountLoaded > 0
	Begin
		exec @myError = LoadSeqInfoAndModsPart2 @job, @message output

		if @myError <> 0
		Begin
			If Len(IsNull(@message, '')) = 0
				Set @message = 'Error calling LoadSeqInfoAndModsPart2 for job ' + @jobStr
			Goto Done
		End
	End
	
Done:
	Return @myError


GO
