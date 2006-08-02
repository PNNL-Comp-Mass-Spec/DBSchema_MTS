SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[LoadXTandemPeptidesBulk]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[LoadXTandemPeptidesBulk]
GO


CREATE Procedure dbo.LoadXTandemPeptidesBulk
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
**	Parameters:
**	
**	Auth:	mem
**	Date:	12/16/2005
**			01/15/2006 mem - Added parameters @PeptideSeqInfoFilePath and @PeptideSeqModDetailsFilePath and added call to LoadSeqInfoAndModsPart1
**			01/25/2006 mem - Now considering @CleavageState and @TerminusState when filtering
**			02/15/2006 mem - Added parameters @PeptideResultToSeqMapFilePath and @PeptideSeqToProteinMapFilePath
**			06/04/2006 mem - Added parameter @LineCountToSkip, which is used during Bulk Insert
**			07/18/2006 mem - Now considering charge state thresholds when filtering data
**			08/01/2006 mem - Added parameter @PeptideProphetResultsFilePath
**
*****************************************************/
(
	@PeptideSynFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_xt.txt',
	@PeptideResultToSeqMapFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_ResultToSeqMap.txt',
	@PeptideSeqInfoFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_SeqInfo.txt',
	@PeptideSeqModDetailsFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_ModDetails.txt',
	@PeptideSeqToProteinMapFilePath varchar(512) = 'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_SeqToProteinMap.txt',
	@PeptideProphetResultsFilePath varchar(512) =  'F:\Temp\QC_05_2_02Dec05_Pegasus_05-11-13_xt_PepProphet.txt',
	@Job int,
	@FilterSetID int,
	@LineCountToSkip int=1,
	@numLoaded int=0 output,
	@numSkipped int=0 output,
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
	set @message = ''

	declare @jobStr varchar(12)
	set @jobStr = convert(varchar(12), @Job)

	declare @Sql varchar(2048)
	declare @UnfilteredCountLoaded int
	set @UnfilteredCountLoaded = 0

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
	
	CREATE CLUSTERED INDEX #IX_Tmp_Peptide_Import_Result_ID ON #Tmp_Peptide_Import (Result_ID)
	CREATE INDEX #IX_Tmp_Peptide_Import_Scan_Number ON #Tmp_Peptide_Import (Scan_Number)

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

	CREATE CLUSTERED INDEX #IX_Tmp_Peptide_ModDetails_Seq_ID ON #Tmp_Peptide_ModDetails (Seq_ID_Local)


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
						@message output

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
			@XTandemLogEValueThreshold real

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
		Set @Sql = @Sql +   ' ( SELECT TPI.Result_ID'
		Set @Sql = @Sql +     ' FROM #Tmp_Peptide_Import TPI INNER JOIN'
		Set @Sql = @Sql +          ' #Tmp_Peptide_ResultToSeqMap RTSM ON TPI.Result_ID = RTSM.Result_ID INNER JOIN'
		Set @Sql = @Sql +          ' #Tmp_Peptide_SeqInfo PSI ON RTSM.Seq_ID_Local = PSI.Seq_ID_Local INNER JOIN'
		Set @Sql = @Sql +          ' #Tmp_Peptide_SeqToProteinMap STPM ON PSI.Seq_ID_Local = STPM.Seq_ID_Local'
		Set @Sql = @Sql +     ' WHERE '
		Set @Sql = @Sql +		   ' STPM.Cleavage_State ' + @CleavageStateComparison + Convert(varchar(6), @CleavageStateThreshold) + ' AND '
		Set @Sql = @Sql +		   ' STPM.Terminus_State ' + @TerminusStateComparison + Convert(varchar(6), @TerminusStateThreshold) + ' AND '
		Set @Sql = @Sql +		   ' TPI.Charge_State ' + @ChargeStateComparison + Convert(varchar(6), @ChargeStateThreshold) + ' AND '
		Set @Sql = @Sql +		   ' TPI.Peptide_Hyperscore ' + @XTandemHyperscoreComparison + Convert(varchar(11), @XTandemHyperscoreThreshold) + ' AND '
		Set @Sql = @Sql +		   ' PSI.Monoisotopic_Mass ' + @MassComparison + Convert(varchar(11), @MassThreshold) + ' AND '
		Set @Sql = @sql +          ' TPI.Peptide_Log_EValue ' + @XTandemLogEValueComparison + Convert(varchar(11), @XTandemLogEValueThreshold)
		Set @Sql = @sql +    ' ) LookupQ ON LookupQ.Result_ID = TFF.Result_ID'
   
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
			Set @Message = 'Error retrieving next entry from GetThresholdsForFilterSet in LoadXTandemPeptidesBulk'
			Goto Done
		End

	End -- While


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
	-- Delete any existing results in T_Peptides, T_Score_XTandem
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


	---------------------------------------------------
	--  Start a transaction
	---------------------------------------------------
	
	declare @numAddedPeptides int
	declare @numAddedXTScores int
	declare @numAddedDiscScores int
	declare @numAddedPepProphetScores int

	declare @transName varchar(32)
	set @transName = 'LoadXTandemPeptidesBulk'
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
		1,						-- Number_of_Scans
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


	If @PeptideProphetCountLoaded > 0
	Begin
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
	End
	Else
		Set @numAddedPepProphetScores = 0

	
	-----------------------------------------------
	-- Copy selected contents of #Tmp_Peptide_Import
	-- into T_Score_XTandem
	-----------------------------------------------
	--
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


	-----------------------------------------------
	-- Verify that all inserts have same number of rows
	-----------------------------------------------
	--
	Set @numAddedPeptides = IsNull(@numAddedPeptides, 0)
	Set @numAddedXTScores = IsNull(@numAddedXTScores, 0)
	Set @numAddedDiscScores = IsNull(@numAddedDiscScores, 0)
	Set @numAddedPepProphetScores = IsNull(@numAddedPepProphetScores, 0)
		
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
	
	if @PeptideProphetCountLoaded > 0 AND @numAddedPeptides <> @numAddedPepProphetScores
	begin
		rollback transaction @transName
		set @message = 'Error in rowcounts for @numAddedPeptides vs @numAddedPepProphetScores for job ' + @jobStr + '; ' + Convert(varchar(12), @numAddedPeptides) + ' <> ' + Convert(varchar(12), @numAddedPepProphetScores)
		Set @myError = 50009
		Set @numLoaded = 0
		goto Done
	end
	
	Set @numLoaded = @numAddedPeptides	


	-----------------------------------------------
	-- Commit changes to T_Peptides, T_Score_XTandem, etc. if we made it this far
	-----------------------------------------------
	--
	commit transaction @transName


	-----------------------------------------------
	-- If @ResultToSeqMapCountLoaded > 0, then call LoadSeqInfoAndModsPart2 
	--  to populate the Candidate Sequence tables (this should always be true)
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

	-----------------------------------------------
	-- Load the Peptide Prophet results file if it exists
	-----------------------------------------------
	
	exec @myError = LoadPeptideProphetResultsOneJob @job, @PeptideProphetResultsFilePath, @message output

	if @myError <> 0
	Begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling LoadPeptideProphetResultsOneJob for job ' + @jobStr
		Goto Done
	End

Done:
	Return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

