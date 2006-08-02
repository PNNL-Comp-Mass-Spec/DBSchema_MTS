SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[LoadSequestPeptidesBulk]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[LoadSequestPeptidesBulk]
GO


CREATE Procedure dbo.LoadSequestPeptidesBulk
/****************************************************
**
**	Desc: 
**		Load peptides from synopsis file into peptides table
**		for given analysis job using bulk loading techniques
**
**		Note: this routine will not load peptides
**			with an XCorr score below minimum thresholds
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	
**
**		Auth: grk
**		Date: 11/11/2001
**
**		Updated: 
**        07/03/2004 mem - Modified procedure to store data in new Peptide DB tables
**                         Added check for existing results for this job in 
**                         the Peptide DB tables; results will be deleted if existing
**        07/16/2004 grk - Use new sequest peptide file extractor (discriminant scoring)
**		  07/21/2004 mem - Added additional @myError statements
**		  08/06/2004 mem - Changed from MH > @LMWtoHMWTransition to MH >= @LMWtoHMWTransition and added IsNull when determining @base
**		  08/24/2004 mem - Switched to using @FilterSetID; added parameter @numSkipped
**		  09/10/2004 mem - Added new filter field: @DiscriminantInitialFilter
**		  09/14/2004 mem - Added parsing out of protein references to reduce duplicate data in T_Peptides
**		  01/03/2005 mem - Now passing 0 to @DropAndAddConstraints when calling DeletePeptidesForJobAndResetToNew
**		  01/27/2005 mem - Fixed bug with @DiscriminantScoreComparison variable length
**		  03/26/2005 mem - Added optional call to CalculateCleavageState
**		  03/26/2005 mem - Updated call to GetThresholdsForFilterSet to include @ProteinCount and @TerminusState criteria
**    
*****************************************************/
	@PeptideSynFilePath varchar(255) = 'F:\GRK\Shew222b-P_06June03_draco_0306-4_7-9_syn.txt',
	@Job int,
	@FilterSetID int,
	@numLoaded int=0 output,
	@numSkipped int=0 output,
	@message varchar(512)='' output
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	set @numLoaded = 0
	set @numSkipped = 0
	set @message = ''

	declare @jobStr varchar(12)
	set @jobStr = cast(@Job as varchar(12))

	declare @Sql varchar(1024)

	declare @CalculateCleavageState int
	
	-----------------------------------------------
	-- See if CalculateCleavageState is enabled
	-----------------------------------------------
	--
	set @CalculateCleavageState = 0
	SELECT @CalculateCleavageState = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'CalculateCleavageState')

	-----------------------------------------------
	-- create temporary table to hold contents 
	-- of synopsis file
	-----------------------------------------------
	--
/***
	Job		Analysis Job ID
	Scan		Scan Number
	Num		Number of Scans
	Chg		Charge State
	MH		(M+H)+
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
	NTT	  	number of tryptic termini, aka Cleavage_State

***/
	CREATE TABLE #T_Peptide_Import (
		ID int NOT NULL ,
		Scan_Number int NULL ,
		Number_Of_Scans smallint NULL ,
		Charge_State smallint NULL ,
		MH float NULL ,
		XCorr real NULL ,
		DeltaCn real NULL ,
		Sp float NULL ,
		Reference varchar (255)  NULL ,
		Multiple_ORF int NULL ,
		Peptide varchar (850) NULL,
		DeltaCn2 real NULL ,
		RankSp real NULL ,
		RankXc real NULL ,
		DelM float NULL ,
		RatioXc real NULL ,
		PassFilt int NULL,
		MScore real NULL,
		Cleavage_State int NULL
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #T_Peptide_Import for job ' + @jobStr
		goto Done
	end
	

	-----------------------------------------------
	-- Also create a table for holding flags of whether or not
	-- the peptides pass the import filter
	-----------------------------------------------
	CREATE TABLE #T_Peptide_Filter_Flags (
		ID int NOT NULL,
		Valid tinyint NOT NULL
	)

	-----------------------------------------------
	-- bulk load contents of synopsis file into temporary table
	-- using bulk loading function
	-----------------------------------------------
	--
	declare @c nvarchar(1024)

	Set @c = 'BULK INSERT #T_Peptide_Import FROM ' + '''' + @PeptideSynFilePath + ''''
	exec @myError = sp_executesql @c
	--
	if @myError <> 0
	begin
		set @message = 'Problem executing bulk insert for job ' + @jobStr
		Set @myError = 50001
		goto Done
	end

	-----------------------------------------------------------
	-- Define the filter threshold values
	-----------------------------------------------------------
	
	Declare @CriteriaGroupStart int,
			@CriteriaGroupMatch int,
			@SpectrumCountComparison varchar(2),		-- Not used in this SP
			@SpectrumCountThreshold int,				-- Not used in this SP
			@ChargeStateComparison varchar(2),			-- Not used in this SP
			@ChargeStateThreshold tinyint,				-- Not used in this SP
			@HighNormalizedScoreComparison varchar(2),
			@HighNormalizedScoreThreshold float,
			@CleavageStateComparison varchar(2),		-- Not used in this SP
			@CleavageStateThreshold tinyint,			-- Not used in this SP
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
			@TerminusStateComparison varchar(2),		-- Not used in this SP
			@TerminusStateThreshold tinyint				-- Not used in this SP

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
									@TerminusStateComparison OUTPUT, @TerminusStateThreshold OUTPUT
	
	if @myError <> 0
	begin
		if len(@message) = 0
			set @message = 'Could not validate filter set ID ' + Convert(varchar(11), @FilterSetID) + ' using GetThresholdsForFilterSet'		
		goto Done
	end
	
	if @CriteriaGroupMatch = 0 
	begin
		set @message = 'Filter set ID ' + Convert(varchar(11), @FilterSetID) + ' not found using GetThresholdsForFilterSet'
		set @myError = 50002
		goto Done
	end

	-----------------------------------------------
	-- Populate #T_Peptide_Filter_Flags	
	-----------------------------------------------
	
	INSERT INTO #T_Peptide_Filter_Flags (ID, Valid)
	SELECT ID, 0
	FROM #T_Peptide_Import
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount

	-----------------------------------------------
	-- Mark peptides that pass the thresholds
	-----------------------------------------------

	While @CriteriaGroupMatch > 0
	Begin

		-- Construct the Sql Update Query
		--
		Set @Sql = ''
		Set @Sql = @Sql + ' UPDATE #T_Peptide_Filter_Flags'
		Set @Sql = @Sql + ' SET Valid = 1'
		Set @sql = @sql + ' FROM #T_Peptide_Filter_Flags AS TFF INNER JOIN '
		Set @sql = @sql + ' #T_Peptide_Import AS TPI ON TFF.ID = TPI.ID'
		Set @Sql = @Sql + ' WHERE '
		Set @Sql = @Sql +	' TPI.XCorr ' + @HighNormalizedScoreComparison +  Convert(varchar(11), @HighNormalizedScoreThreshold) + ' AND '
		Set @Sql = @Sql +	' TPI.MH ' + @MassComparison + Convert(varchar(11), @MassThreshold) + ' AND '
		Set @Sql = @Sql +	' TPI.DeltaCn ' + @DeltaCnComparison + Convert(varchar(11), @DeltaCnThreshold) + ' AND '
		Set @Sql = @sql +   ' TPI.PassFilt ' + @DiscriminantInitialFilterComparison + Convert(varchar(11), @DiscriminantInitialFilterThreshold)

		-- Execute the Sql to update the matching entries
		Exec (@Sql)
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
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
										@TerminusStateComparison OUTPUT, @TerminusStateThreshold OUTPUT
		If @myError <> 0
		Begin
			Set @Message = 'Error retrieving next entry from GetThresholdsForFilterSet in LoadSequestPeptidesBulk'
			Goto Done
		End

	End -- While


	-----------------------------------------------
	-- Remove peptides falling below threshold
	-- In case the input file has an entry with an 
	-- ID value of 0, we're using > 0 for the check
	-----------------------------------------------
	DELETE #T_Peptide_Import
	FROM #T_Peptide_Filter_Flags AS TFF INNER JOIN
		 #T_Peptide_Import AS TPI ON TFF.ID = TPI.ID
	WHERE TFF.Valid = 0
	--
	SELECT @myError = @@error, @numSkipped = @@RowCount


	---------------------------------------------------
	--  Start transaction
	---------------------------------------------------
	
	declare @numAddedPeptides int
	declare @numAddedSeqScores int
	declare @numAddedDiscScores int

	declare @transName varchar(32)
	set @transName = 'LoadSequestPeptidesBulk'
	begin transaction @transName

	-----------------------------------------------
	-- Get base value for peptide ID calculation
	-----------------------------------------------
	--
	declare @base int
	set @base = 0
	--
	SELECT  @base = IsNull(MAX(Peptide_ID) + 1, 1000)
	FROM T_Peptides
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0 or @base = 0
	begin
		rollback transaction @transName
		set @message = 'Problem getting base for peptide ID for job ' + @jobStr
		If @myError = 0
			Set @myError = 50003
		goto Done
	end

	-----------------------------------------------
	-- Update peptide ID column
	-----------------------------------------------
	--
	update #T_Peptide_Import
	set ID = @base + ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Problem updating ID column in temporary table for job ' + @jobStr
		goto Done
	end

	-----------------------------------------------
	-- Delete any existing results in T_Peptides, T_Score_Sequest
	-- T_Score_Discriminant, etc. for this analysis job
	-----------------------------------------------
	Exec @myError = DeletePeptidesForJobAndResetToNew @job, 0, 0, 0
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Problem deleting existing peptide entries for job ' + @jobStr
		Set @myError = 50004
		goto Done
	end

	-----------------------------------------------
	-- Make sure all peptides in #T_Peptide_Import have
	-- a Scan Number, Charge, and Peptide defined
	-- Delete any that do not
	-----------------------------------------------
	DELETE FROM #T_Peptide_Import 
	WHERE Scan_Number Is Null OR Charge_State Is Null OR Peptide Is Null
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
	-- If no peptides remain in #T_Peptide_Import then
	-- commit the transaction, but jump to Done
	-----------------------------------------------
	SELECT @myRowCount = Count(*)
	FROM #T_Peptide_Import
	--
	If @myRowCount = 0
	Begin
		Set @numLoaded = @myRowCount
		Goto FinalizeTransaction
	End
	
	-----------------------------------------------
	-- Make sure all peptides in #T_Peptide_Import have
	-- a reference defined; if any do not, give them
	-- a bogus reference name and post an entry to the log
	-----------------------------------------------
	UPDATE #T_Peptide_Import
	SET Reference = 'xx_Unknown_Protein_Reference_xx'
	WHERE Reference Is Null
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
	-- Make sure all peptides in #T_Peptide_Import have
	-- an MH defined; if they don't, assign a value of 0
	-----------------------------------------------
	UPDATE #T_Peptide_Import
	SET MH = 0
	WHERE MH Is Null
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
	-- minimum Peptide_ID value for each unique 
	-- combination of Scan_Number, Charge_State, MH, Peptide
	-----------------------------------------------

	CREATE TABLE #T_Unique_Records (
		Peptide_ID int NOT NULL ,
		Scan_Number int NOT NULL ,
		Charge_State smallint NOT NULL ,
		MH float NOT NULL ,
		Peptide varchar (850) NOT NULL
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Problem creating temporary table #T_Unique_Records for job ' + @jobStr
		goto Done
	end

	INSERT INTO #T_Unique_Records (Peptide_ID, Scan_Number, Charge_State, MH, Peptide)
	SELECT MIN(ID), Scan_Number, Charge_State, MH, Peptide
	FROM #T_Peptide_Import
	GROUP BY Scan_Number, Charge_State, MH, Peptide
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Problem populating temporary table #T_Unique_Records ' + @jobStr
		goto Done

	end
	--
	if @myRowCount = 0
	Begin
		rollback transaction @transName
		set @message = '#T_Unique_Records table populated with no records for job ' + @jobStr
		goto Done
	End
	

	-----------------------------------------------
	-- Add new references to T_Proteins
	-----------------------------------------------
	INSERT INTO T_Proteins (Reference)
	SELECT TPI.Reference
	FROM #T_Peptide_Import AS TPI LEFT OUTER JOIN T_Proteins ON
		TPI.Reference = T_Proteins.Reference
	WHERE T_Proteins.Reference Is Null
	GROUP BY TPI.Reference
	ORDER BY TPI.Reference
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
	-- copy selected contents of temporary table 
	-- into peptides table
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
		TPI.ID,
		@Job,	
		TPI.Scan_Number,
		TPI.Number_Of_Scans,
		TPI.Charge_State,
		TPI.MH,
		TPI.Multiple_ORF,
		TPI.Peptide
	FROM #T_Peptide_Import AS TPI INNER JOIN 
		 #T_Unique_Records AS UR ON TPI.ID = UR.Peptide_ID
	ORDER BY TPI.ID
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
	-- copy selected contents of temporary table 
	-- into discriminant scoring table
	-----------------------------------------------
	
	INSERT INTO T_Score_Discriminant
		(Peptide_ID, MScore, PassFilt)
	SELECT
		TPI.ID, TPI.MScore, TPI.PassFilt
	FROM #T_Peptide_Import AS TPI INNER JOIN 
		 #T_Unique_Records AS UR ON TPI.ID = UR.Peptide_ID
	ORDER BY TPI.ID
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
	
	-----------------------------------------------
	-- copy selected contents of temporary table 
	-- into Sequest scoring table
	-----------------------------------------------

	INSERT INTO T_Score_Sequest
		(Peptide_ID, XCorr, DeltaCn, DeltaCn2, Sp, RankSp, RankXc, DelM, XcRatio)
	SELECT
		TPI.ID,
		TPI.XCorr,
		TPI.DeltaCn,
		TPI.DeltaCn2,
		TPI.Sp,
		TPI.RankSp,
		TPI.RankXc,
		TPI.DelM,
		TPI.RatioXc
	FROM #T_Peptide_Import AS TPI INNER JOIN 
		 #T_Unique_Records AS UR ON TPI.ID = UR.Peptide_ID
	ORDER BY TPI.ID
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
	-- copy selected contents of temporary table into T_Peptide_to_Protein_Map table; 
	-- we shouldn't have to use the Group By when inserting, but if the synopsis file 
	-- has multiple entries for the same combination of Scan_Number, Charge_State, MH
	-- and Peptide pointing to the same Reference, then this will cause a primary
	-- key constraint error
	-----------------------------------------------
	INSERT INTO T_Peptide_to_Protein_Map (Peptide_ID, Ref_ID, Cleavage_State)
	SELECT UR.Peptide_ID, T_Proteins.Ref_ID, MAX(IsNull(TPI.Cleavage_State, 0))
	FROM #T_Unique_Records AS UR INNER JOIN #T_Peptide_Import AS TPI ON
		 UR.Scan_Number = TPI.Scan_Number AND
		 UR.Charge_State = TPI.Charge_State AND
		 UR.MH = TPI.MH AND
		 UR.Peptide = TPI.Peptide INNER JOIN T_Proteins ON
		 TPI.Reference = T_Proteins.Reference
	GROUP BY UR.Peptide_ID, T_Proteins.Ref_ID
	ORDER BY UR.Peptide_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Error inserting into T_Peptide_to_Protein_Map for job ' + @jobStr
		goto Done
	end


	If @CalculateCleavageState <> 0
	Begin
		Exec @myError = CalculateCleavageState @JobFilter = @Job, @reprocess = 1, @logLevel = 0, @message = @message OUTPUT
		--
		if @myError <> 0
		begin
			rollback transaction @transName
			If Len(@Message) = 0
				set @message = 'Error calling CalculateCleavageState for job ' + @jobStr
			goto Done
		end

	End

	-----------------------------------------------
	-- verify that all inserts have same number of rows
	-----------------------------------------------

	if (@numAddedPeptides <> @numAddedSeqScores) or (@numAddedSeqScores <> @numAddedDiscScores) or (@numAddedPeptides <> @numAddedDiscScores)
	begin
		rollback transaction @transName
		set @message = 'Error in rowcounts for multiple table inserts for job ' + @jobStr
		Set @myError = 50005
		Set @numLoaded = 0
		goto Done
	end
	
	Set @numLoaded = @numAddedPeptides


	-----------------------------------------------
	-- commit changes if we made it this far
	-----------------------------------------------
	--
FinalizeTransaction:
	commit transaction @transName


Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

