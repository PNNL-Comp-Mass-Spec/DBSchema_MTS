/****** Object:  StoredProcedure [dbo].[UpdateMassTagsFromOneAnalysis] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.UpdateMassTagsFromOneAnalysis
/****************************************************
** 
**		Desc: 
**			Retrieves all peptides from the
**			associated peptide database for the 
**			given analysis job according to filter
**			criteria.
**
**			Reconciles them with appropriate entries in T_Mass_Tags
**			and populates T_Mass_Tags_to_Protein_Map, T_Protein_Reference, 
**			T_Peptides, and the T_Score tables
**
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**	Auth:	grk
**	Date:	11/16/2001
**			09/16/2003 grk - Added table lookup for allowed filters
**			01/27/2004 mem - Added code to delete peptides from #Imported_Peptides that already exist in T_Peptides
**			07/21/2004 mem - Added check for empty T_Import_Cleavage_Filter_List table; if empty, then imports all peptides for given jobs
**			09/28/2004 mem - Updated to use @PeptideDBName and to populate additional tables
**			01/23/2005 mem - Now populating T_Peptides.Scan_Time_Peak_Apex
**						   - Now raising an error if no peptides are imported for a job
**						   - Now validating that the maximum peptide_hit scan number is less than the maximum SIC scan number
**			01/30/2005 mem - Updated population of #ImportedMassTags to be tolerant of conflicting Multiple_ORF or GANET_Predicted values
**			03/26/2005 mem - Now populating Terminus_State in Mass_Tag_to_Protein_Map
**						   - Now checking for conflicting Cleavage_State or Terminus_State values when importing values into Mass_Tag_to_Protein_Map
**			05/09/2005 mem - Added checking that given job has been tested in the Peptide DB against at least one of the peptide import filter IDs in T_Process_Config
**			05/20/2005 mem - Now updating field Internal_Standard_Only to 0 for any new mass tags
**			09/02/2005 mem - Now populating columns Peak_Area and Peak_SN_Ratio in T_Peptides
**			10/09/2005 mem - Now calling ComputeMaxObsAreaByJob to populate Max_Obs_Area_In_Job in T_Peptides
**			12/01/2005 mem - Added brackets around @PeptideDBName as needed to allow for DBs with dashes in the name
**			12/11/2005 mem - Updated to support XTandem results
**			07/10/2006 mem - Updated to support Peptide Prophet values
**			09/12/2006 mem - Now populating column RowCount_Loaded
**			09/19/2006 mem - Replaced parameter @PeptideDBName with @PeptideDBPath
**			02/25/2008 mem - Moved Commit Transaction statement to earlier in the processing to reduce the overhead required
**			04/04/2008 mem - Now updating Cleavage_State_Max in T_Mass_Tags
**
*****************************************************/
(
	@job int,
	@PeptideDBPath varchar(256),				-- Should be of the form ServerName.[DatabaseName] or simply [DatabaseName]
	@numAddedPeptides int = 0 output,
	@message varchar(512) = '' output 
)
As
	set nocount on
	
	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @message = ''
	set @numAddedPeptides = 0
	
	declare @result int
	declare @numAddedPeptideHitScores int
	declare @numAddedDiscScores int
	declare @errorReturn int
	declare @matchCount int
	
	set @errorReturn = 0

	declare @S nvarchar(3000)
	declare @ParamDef nvarchar(512)

	declare @transName varchar(32)
	declare @jobStr varchar(19)
	declare @ResultType varchar(64)

	set @jobStr = Convert(varchar(19), @job)


	---------------------------------------------------
	-- Count number of import filters defined
	---------------------------------------------------
	declare @ImportFilterCount int
	set @ImportFilterCount = 0
	--
	SELECT @ImportFilterCount = Count(*)
	FROM T_Process_Config
	WHERE [Name] = 'Peptide_Import_Filter_ID' AND Len(Value) > 0
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Could not count number of import filters defined'
		set @myError = 50000
		goto Done
	end
	
	
	If @ImportFilterCount > 0
	Begin
		---------------------------------------------------
		-- Validate that the given Peptide DB has tested this job against one of the 
		-- filters in T_Process_Config; if it has not, then raise an error
		---------------------------------------------------

		set @matchCount = 0
		
		set @S = ''
		set @S = @S + ' SELECT @matchCount = Count(Job) '
		set @S = @S + ' FROM '
		set @S = @S +    ' ' + @PeptideDBPath + '.dbo.T_Analysis_Filter_Flags'
		set @S = @S + ' WHERE (Job = ' + @jobStr + ') '
		set @S = @S + ' AND ('
		set @S = @S + '    Filter_ID IN '
		set @S = @S + '    (SELECT Value FROM T_Process_Config WHERE [Name] = ''Peptide_Import_Filter_ID'' AND Len(Value) > 0)'
		set @S = @S + ') '

		set @ParamDef = '@matchCount int output'
		
		exec @result = sp_executesql @S, @ParamDef, @matchCount = @matchCount output
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If IsNull(@matchCount, 0) = 0
		Begin
			set @message = 'Job ' + @jobStr + ' has not yet been tested in peptide DB ' + @PeptideDBPath + ' against any of the import filters defined in T_Process_Config; thus, no peptides can be imported'
			set @myError = 50001
			goto Done
		End
	End
	
	-----------------------------------------------------------
	-- Lookup the ResultType for this job
	-----------------------------------------------------------
	Set @ResultType = ''
	SELECT @ResultType = IsNull(ResultType, '')
	FROM T_Analysis_Description
	WHERE Job = @Job
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myError <> 0
	Begin
		set @message = 'Error looking up ResultType for Job ' + @jobStr + ' (Error = ' + Convert(varchar(19), @myError) + ')'
		set @myError = 50002
		goto Done
	End
	
	If @myRowCount = 0
	Begin
		set @message = 'Job ' + @jobStr + ' not found in T_Analysis_Description'
		set @myError = 50003
		goto Done
	End
	
	
	-----------------------------------------------------------
	-- create temporary table for import of peptides
	-----------------------------------------------------------
	--
	CREATE TABLE #Imported_Peptides (
		Scan_Number int,
		Number_Of_Scans smallint,
		Charge_State smallint,
		MH float,
		Monoisotopic_Mass float, 
		GANET_Obs real,
		GANET_Predicted real,
		Scan_Time_Peak_Apex real,
		Multiple_ORF int, 
		Peptide varchar (850), 
		Clean_Sequence varchar (850), 
		Mod_Count int, 
		Mod_Description varchar (2048), 
		Seq_ID int, 
		Peptide_ID_Original int NOT NULL,
		Peak_Area float,
		Peak_SN_Ratio real,
		Unique_Row_ID int IDENTITY (1, 1) NOT NULL,
		Peptide_ID_New int NULL
	)   
	--
	SELECT @myError = @@error
	--
	if @myError <> 0 
	begin
		set @message = 'Could not create #Imported_Peptides temporary table'
		set @myError = 50004
		goto Done
	end

	-----------------------------------------------
	-- Add index to #Imported_Peptides to speed joins
	-- on column Peptide_ID_Original
	-----------------------------------------------
	--
	CREATE UNIQUE CLUSTERED INDEX #IX_TempTable_Imported_Peptides_ID_Original ON #Imported_Peptides (Peptide_ID_Original)
	CREATE INDEX #IX_TempTable_Imported_Peptides_ID_New ON #Imported_Peptides (Peptide_ID_New)


	-----------------------------------------------------------
	-- create temporary table for import of peptide to protein mappings
	-----------------------------------------------------------
	--
	CREATE TABLE #PeptideToProteinMapImported (
		Seq_ID int, 
		Cleavage_State tinyint,
		Terminus_State tinyint,
		Reference varchar(255),
		Ref_ID_New int NULL
	)
	--
	SELECT @myError = @@error
	--
	if @myError <> 0 
	begin
		set @message = 'Could not create #PeptideToProteinMapImported temporary table'
		set @myError = 50005
		goto Done
	end

	-----------------------------------------------
	-- Add index to #Imported_Peptides to speed joins
	-- on column Reference
	-----------------------------------------------
	--
	CREATE INDEX #IX_TempTable_PeptideToProteinMapImported ON #PeptideToProteinMapImported (Reference)
    
	-----------------------------------------------------------
	-- create temporary table to hold unique Mass Tag ID stats
	-----------------------------------------------------------
	--
	CREATE TABLE #ImportedMassTags (
		Mass_Tag_ID int NOT NULL,
		Clean_Sequence varchar (850), 
		Monoisotopic_Mass float, 
		Multiple_ORF int,
		Mod_Count int, 
		Mod_Description varchar (2048), 
		GANET_Predicted real
	)   
	--
	SELECT @myError = @@error
	--
	if @myError <> 0 
	begin
		set @message = 'Could not create #ImportedMassTags temporary table'
		set @myError = 50006
		goto Done
	end

	-----------------------------------------------
	-- Add index to #ImportedMassTags to assure no 
	-- duplicate Mass_Tag_ID rows are present
	-----------------------------------------------
	--
	CREATE UNIQUE CLUSTERED INDEX #IX_TempTable_ImportedMassTags ON #ImportedMassTags (Mass_Tag_ID)

	-----------------------------------------------------------
	-- create temporary table to hold peptide hit stats
	-----------------------------------------------------------
	--
	CREATE TABLE #PeptideHitStats (
		Mass_Tag_ID int NOT NULL,
		Observation_Count int NOT NULL, 
		Normalized_Score_Max real NULL
	)   
	--
	SELECT @myError = @@error
	--
	if @myError <> 0 
	begin
		set @message = 'Could not create #PeptideHitStats temporary table'
		set @myError = 50006
		goto Done
	end

	-----------------------------------------------
	-- Add index to #PeptideHitStats to assure no 
	-- duplicate Mass_Tag_ID rows are present
	-----------------------------------------------
	--
	CREATE UNIQUE CLUSTERED INDEX #IX_TempTable_PeptideHitStats ON #PeptideHitStats (Mass_Tag_ID)
	
	
	-----------------------------------------------------------
	-- build dynamic SQL and execute it to populate
	-- #Imported_Peptides from @PeptideDBPath
	-----------------------------------------------------------
	--
	declare @numPeptidesImported int
	set @numPeptidesImported = 0

	set @S = ''
	set @S = @S + 'INSERT INTO #Imported_Peptides '
	set @S = @S + '( '
	set @S = @S + ' Scan_Number, Number_Of_Scans, Charge_State, MH,'
	set @S = @S + ' Monoisotopic_Mass, GANET_Obs, GANET_Predicted, Scan_Time_Peak_Apex, Multiple_ORF,'
	set @S = @S + ' Peptide, Clean_Sequence, Mod_Count, Mod_Description,'
	set @S = @S + ' Seq_ID, Peptide_ID_Original, Peak_Area, Peak_SN_Ratio'
	set @S = @S + ') '
	--
	set @S = @S + 'SELECT '
	set @S = @S + ' Scan_Number, Number_Of_Scans, Charge_State, MH,'
	set @S = @S + ' Monoisotopic_Mass, GANET_Obs, GANET_Predicted,  Scan_Time_Peak_Apex, Multiple_ORF,'
	set @S = @S + ' Peptide, Clean_Sequence, Mod_Count, Mod_Description,'
	set @S = @S + ' Seq_ID, Peptide_ID, Peak_Area, Peak_SN_Ratio '
	set @S = @S + 'FROM '
	set @S = @S +   ' ' + @PeptideDBPath + '.dbo.V_Peptide_Export '
	set @S = @S + 'WHERE (Analysis_ID = ' + @jobStr + ') '

	if @ImportFilterCount > 0
	begin
		set @S = @S + 'AND ('
		set @S = @S + '    Filter_ID IN '
		set @S = @S + '    (SELECT Value FROM T_Process_Config WHERE [Name] = ''Peptide_Import_Filter_ID'' AND Len(Value) > 0)'
		set @S = @S + ') '
	end
	  
	exec @result = sp_executesql @S
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	set @numPeptidesImported = @myRowCount
	--
	if @result <> 0 
	begin
		set @message = 'Error executing dynamic SQL for peptide import for job ' + @jobStr
		set @myError = 50007
		goto Done
	end

	-----------------------------------------------------------
	-- we are done if we didn't get any peptides
	-----------------------------------------------------------
	--
	if @numPeptidesImported <= 0 
	begin
		set @message = 'No peptides imported for job ' + @jobStr
		set @myError = 60000
		goto Done
	end

	-----------------------------------------------------------
	-- Perform some scan number checks to validate that the 
	-- SIC job associated with this Peptide_Hit job is valid
	-----------------------------------------------------------
	--
	Declare @MaxScanNumberPeptideHit int,
			@MaxScanNumberSICs int,
			@MaxScanNumberAllScans int

	Set @MaxScanNumberPeptideHit = 0
	Set @MaxScanNumberSICs = 0
	Set @MaxScanNumberAllScans = 0

	set @S = ''
	set @S = @S + ' SELECT @MaxA = MaxScanNumberPeptideHit, '
	set @S = @S +        ' @MaxB = MaxScanNumberSICs,'
	set @S = @S +        ' @MaxC = MaxScanNumberAllScans'
	set @S = @S + ' FROM ' + @PeptideDBPath + '.dbo.V_PeptideHit_Job_Scan_Max'
	set @S = @S + ' WHERE (Job = ' + @jobStr + ') '

	set @ParamDef = '@MaxA int output, @MaxB int output, @MaxC int output'
	
	exec @result = sp_executesql @S, @ParamDef, @MaxA = @MaxScanNumberPeptideHit output, @MaxB = @MaxScanNumberSICs output, @MaxC = @MaxScanNumberAllScans output

	Set @MaxScanNumberPeptideHit = IsNull(@MaxScanNumberPeptideHit,0)
	
	If @MaxScanNumberPeptideHit > IsNull(@MaxScanNumberSICs, 0)
	Begin
		-- Invalid SIC data
		set @message = 'Missing or invalid SIC data found for job ' + @jobStr + '; max Peptide_Hit scan number is greater than maximum SIC scan number'
		set @myError = 60001
		goto Done
	End

	If @MaxScanNumberPeptideHit > IsNull(@MaxScanNumberAllScans, 0)
	Begin
		-- Invalid SIC data
		set @message = 'Missing or invalid SIC data found for job ' + @jobStr + '; max Peptide_Hit scan number is greater than maximum scan stats scan number'
		set @myError = 60002
		goto Done
	End


	-----------------------------------------------------------
	-- Populate #ImportedMassTags
	-----------------------------------------------------------
	INSERT INTO #ImportedMassTags (
		Mass_Tag_ID, Clean_Sequence, Monoisotopic_Mass,
		Multiple_ORF, Mod_Count, Mod_Description, GANET_Predicted
		)
	SELECT Seq_ID, Clean_Sequence, Monoisotopic_Mass,
		   Max(Multiple_ORF), Mod_Count, Mod_Description, Avg(GANET_Predicted)
	FROM #Imported_Peptides
	GROUP BY Seq_ID, Clean_Sequence, Monoisotopic_Mass, Mod_Count, Mod_Description
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error populating #ImportedMassTags temporary table job ' + @jobStr
		set @myError = 50008
		goto Done
	end	

	-----------------------------------------------------------
	-- Populate #PeptideToProteinMapImported
	-----------------------------------------------------------

	set @S = ''
	set @S = @S + 'INSERT INTO #PeptideToProteinMapImported '
	set @S = @S + '( '
	set @S = @S + ' Seq_ID, Cleavage_State, Terminus_State, Reference'
	set @S = @S + ') '
	--
	set @S = @S + 'SELECT'
	set @S = @S + ' VPE.Seq_ID, VPE.Cleavage_State, VPE.Terminus_State, VPE.Reference '
	set @S = @S + 'FROM '
	set @S = @S +   ' ' + @PeptideDBPath + '.dbo.V_Protein_Export AS VPE INNER JOIN'
	set @S = @S + ' #Imported_Peptides AS IP ON '
	set @S = @S + ' IP.Peptide_ID_Original = VPE.Peptide_ID '
	set @S = @S + 'GROUP BY VPE.Seq_ID, VPE.Cleavage_State, VPE.Terminus_State, VPE.Reference'
	  
	exec @result = sp_executesql @S
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	set @numPeptidesImported = @myRowCount
	--
	if @result <> 0 
	begin
		set @message = 'Error executing dynamic SQL for peptide to protein map import'
		set @myError = 50009
		goto Done
	end
    
	-----------------------------------------------
	-- Delete any existing results in T_Peptides, T_Score_Sequest
	-- T_Score_Discriminant, etc. for this analysis job
	-----------------------------------------------
	Exec @result = DeletePeptidesForJobAndResetToNew @job, 0

	-----------------------------------------------
	-- Lookup the maximum Peptide_ID value in T_Peptides
	--  and use it to populate Peptide_ID_New
	-- Start a transaction to assure that the @base value
	--  stays valid
	-----------------------------------------------
	--
	set @transName = 'UpdateMassTagsFromOneAnalysis'
	begin transaction @transName

	-----------------------------------------------
	-- Get base value for peptide ID calculation
	-- Note that @base will get added to #Imported_Peptides.Unique_Row_ID, 
	--  which will always start at 1
	-----------------------------------------------
	--
	declare @base int
	set @base = 0
	--
	SELECT @base = IsNull(MAX(Peptide_ID), 1000)
	FROM T_Peptides
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0 or @base = 0
	begin
		rollback transaction @transName
		set @message = 'Problem getting base for peptide ID for job ' + @jobStr
		If @myError = 0
			Set @myError = 50010
		goto Done
	end

	-----------------------------------------------
	-- Update peptide ID column
	-----------------------------------------------
	--
	UPDATE #Imported_Peptides
	SET Peptide_ID_New = Unique_Row_ID + @base
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Problem populating Peptide_ID_New column in temporary table for job ' + @jobStr
		Set @myError = 50011
		goto Done
	end

	-----------------------------------------------------------
	-- Update existing entries in T_Mass_Tags with Multiple_Proteins
	-- values smaller than those in #ImportedMassTags
	-----------------------------------------------------------
	--
	UPDATE T_Mass_Tags
	SET Multiple_Proteins = IMT.Multiple_ORF
	FROM #ImportedMassTags AS IMT INNER JOIN
	    T_Mass_Tags ON IMT.Mass_Tag_ID = T_Mass_Tags.Mass_Tag_ID
	WHERE T_Mass_Tags.Multiple_Proteins < IMT.Multiple_ORF
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Problem updating Multiple_Proteins values in T_Mass_Tags for job ' + @jobStr
		Set @myError = 50012
		goto Done
	end


	-----------------------------------------------------------
	-- Set Internal_Standard_Only to 0 for matching mass tags
	-----------------------------------------------------------
	--
	UPDATE T_Mass_Tags
	SET Internal_Standard_Only = 0
	FROM #ImportedMassTags AS IMT INNER JOIN
	     T_Mass_Tags ON IMT.Mass_Tag_ID = T_Mass_Tags.Mass_Tag_ID
	WHERE Internal_Standard_Only <> 0
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


	-----------------------------------------------------------
	-- Add new mass tags to T_Mass_Tags
	-----------------------------------------------------------
	--
	INSERT INTO T_Mass_Tags (
		Mass_Tag_ID, Peptide, Monoisotopic_Mass,
		Is_Confirmed, Multiple_Proteins, Created, Last_Affected,
		Number_Of_Peptides, High_Normalized_Score,
		Mod_Count, Mod_Description, Internal_Standard_Only
		)
	SELECT IMT.Mass_Tag_ID, IMT.Clean_Sequence, IMT.Monoisotopic_Mass,
		0 AS Is_Confirmed, IMT.Multiple_ORF, GetDate() AS Created, GetDate() AS Last_Affected,
		0 AS Number_Of_Peptides, 0 AS High_Normalized_Score,
		IMT.Mod_Count, IMT.Mod_Description, 0 AS Internal_Standard_Only
	FROM #ImportedMassTags AS IMT LEFT OUTER JOIN
	    T_Mass_Tags ON IMT.Mass_Tag_ID = T_Mass_Tags.Mass_Tag_ID
	WHERE (T_Mass_Tags.Mass_Tag_ID IS NULL)
	ORDER BY IMT.Mass_Tag_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Problem appending new entries to T_Mass_Tags for job ' + @jobStr
		Set @myError = 50013
		goto Done
	end

	-----------------------------------------------------------
	-- Add new entries to T_Peptides
	-----------------------------------------------------------
	--
	INSERT INTO T_Peptides (
		Peptide_ID, Analysis_ID, Scan_Number, Number_Of_Scans, Charge_State, MH,
		Multiple_Proteins, Peptide, Mass_Tag_ID, GANET_Obs, State_ID, Scan_Time_Peak_Apex,
		Peak_Area, Peak_SN_Ratio
		)
	SELECT Peptide_ID_New, @job, Scan_Number, Number_Of_Scans, Charge_State, MH,
		Multiple_ORF, Peptide, Seq_ID, GANET_Obs, 2 As StateCandidate, Scan_Time_Peak_Apex,
		Peak_Area, Peak_SN_Ratio
	FROM #Imported_Peptides
	ORDER BY Peptide_ID_New
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Problem appending new entries to T_Peptides for job ' + @jobStr
		Set @myError = 50020
		goto Done
	end
	--
	Set @numAddedPeptides = @myRowCount


	Declare @ResultTypeValid tinyint
	Set @ResultTypeValid = 0
	
	If @ResultType = 'Peptide_Hit'
	Begin
		-----------------------------------------------------------
		-- Add new entries to T_Score_Sequest
		-----------------------------------------------------------
		--
		set @S = ''
		set @S = @S + ' INSERT INTO T_Score_Sequest ('
		set @S = @S +   ' Peptide_ID, XCorr, DeltaCn, DeltaCn2, SP, RankSp, RankXc, DelM, XcRatio'
		set @S = @S + ' )'
		set @S = @S + ' SELECT IP.Peptide_ID_New, SS.XCorr, SS.DeltaCn, SS.DeltaCn2, SS.SP, SS.RankSp, SS.RankXc, SS.DelM, SS.XcRatio'
		set @S = @S + ' FROM #Imported_Peptides AS IP INNER JOIN'
		set @S = @S +   ' ' + @PeptideDBPath + '.dbo.T_Score_Sequest AS SS ON IP.Peptide_ID_Original = SS.Peptide_ID'
		set @S = @S + ' ORDER BY IP.Peptide_ID_New'
		--
		exec @result = sp_executesql @S
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @result <> 0 
		begin
			rollback transaction @transName
			set @message = 'Error executing dynamic SQL for T_Score_Sequest for job ' + @jobStr
			set @myError = 50021
			goto Done
		end
		--
		Set @numAddedPeptideHitScores = @myRowCount

		-- Populate #PeptideHitStats (used below to update stats in T_Mass_Tags)
		--
		INSERT INTO #PeptideHitStats (Mass_Tag_ID, Observation_Count, Normalized_Score_Max)
		SELECT	Mass_Tag_ID, 
				COUNT(*) AS Observation_Count, 
				MAX(XCorr_Max) AS Normalized_Score_Max
		FROM (	SELECT	IP.Seq_ID AS Mass_Tag_ID, 
						IP.Scan_Number, 
						MAX(ISNULL(SS.XCorr, 0)) AS XCorr_Max
				FROM #Imported_Peptides AS IP LEFT OUTER JOIN
					 T_Score_Sequest AS SS ON IP.Peptide_ID_New = SS.Peptide_ID
				GROUP BY IP.Seq_ID, IP.Scan_Number
				) AS SubQ
		GROUP BY SubQ.Mass_Tag_ID	
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		Set @ResultTypeValid = 1
	End

	If @ResultType = 'XT_Peptide_Hit'
	Begin
		-----------------------------------------------------------
		-- Add new entries to T_Score_XTandem
		-----------------------------------------------------------
		--
		set @S = ''
		set @S = @S + 'INSERT INTO T_Score_XTandem ('
		set @S = @S +  ' Peptide_ID, Hyperscore, Log_EValue, DeltaCn2,'
		set @S = @S +  ' Y_Score, Y_Ions, B_Score, B_Ions, DelM, Intensity, Normalized_Score'
		set @S = @S + ' )'
		set @S = @S + ' SELECT IP.Peptide_ID_New, X.Hyperscore, X.Log_EValue, X.DeltaCn2,'
		set @S = @S +        ' X.Y_Score, X.Y_Ions, X.B_Score, X.B_Ions, X.DelM, X.Intensity, X.Normalized_Score'
		set @S = @S + ' FROM #Imported_Peptides AS IP INNER JOIN'
		set @S = @S +   ' ' + @PeptideDBPath + '.dbo.T_Score_XTandem AS X ON IP.Peptide_ID_Original = X.Peptide_ID'
		set @S = @S + ' ORDER BY IP.Peptide_ID_New'
		--
		exec @result = sp_executesql @S
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @result <> 0 
		begin
			rollback transaction @transName
			set @message = 'Error executing dynamic SQL for T_Score_XTandem for job ' + @jobStr
			set @myError = 50022
			goto Done
		end
		--
		Set @numAddedPeptideHitScores = @myRowCount
		
		-- Populate #PeptideHitStats (used below to update stats in T_Mass_Tags)
		--
		INSERT INTO #PeptideHitStats (Mass_Tag_ID, Observation_Count, Normalized_Score_Max)
		SELECT	Mass_Tag_ID, 
				COUNT(*) AS Observation_Count, 
				MAX(Normalized_Score_Max) AS Normalized_Score_Max
		FROM (	SELECT	IP.Seq_ID AS Mass_Tag_ID, 
						IP.Scan_Number, 
						MAX(ISNULL(X.Normalized_Score, 0)) AS Normalized_Score_Max
				FROM #Imported_Peptides AS IP LEFT OUTER JOIN
					 T_Score_XTandem AS X ON IP.Peptide_ID_New = X.Peptide_ID
				GROUP BY IP.Seq_ID, IP.Scan_Number
				) AS SubQ
		GROUP BY SubQ.Mass_Tag_ID	
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		Set @ResultTypeValid = 1
	End

	If @ResultTypeValid = 0
	Begin
		rollback transaction @transName
		set @message = 'Job ' + @jobStr + ' does not have a valid ResultType (' + @ResultType + ')'
		set @myError = 50023
		goto Done	
	End

	-----------------------------------------------------------
	-- Add new entries to T_Score_Discriminant
	-- Note that PassFilt and MScore are estimated for XTandem data
	--  PassFilt was set to 1
	--  MScore was set to 10.75
	-----------------------------------------------------------
	--
	set @S = ''
	set @S = @S + ' INSERT INTO T_Score_Discriminant ('
	set @S = @S +  ' Peptide_ID, MScore, DiscriminantScore, DiscriminantScoreNorm,'
	set @S = @S +  ' PassFilt, Peptide_Prophet_FScore, Peptide_Prophet_Probability'
	set @S = @S + ' )'
	set @S = @S + ' SELECT IP.Peptide_ID_New, MScore, DiscriminantScore, DiscriminantScoreNorm,'
	set @S = @S +        ' PassFilt, Peptide_Prophet_FScore, Peptide_Prophet_Probability'
	set @S = @S + ' FROM #Imported_Peptides AS IP INNER JOIN'
	set @S = @S +   ' ' + @PeptideDBPath + '.dbo.T_Score_Discriminant AS SD ON IP.Peptide_ID_Original = SD.Peptide_ID'
	set @S = @S + ' ORDER BY IP.Peptide_ID_New'
	--
	exec @result = sp_executesql @S
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @result <> 0 
	begin
		rollback transaction @transName
		set @message = 'Error executing dynamic SQL for T_Score_Discriminant for job ' + @jobStr
		set @myError = 50024
		goto Done
	end
	--
	Set @numAddedDiscScores = @myRowCount

	If @numAddedPeptideHitScores <> @numAddedPeptides OR @numAddedDiscScores <> @numAddedPeptides
	Begin
		rollback transaction @transName
		set @message = 'Analysis counts not identical for job ' + @jobStr + '; ' + convert(varchar(11), @numAddedPeptides) + ' vs. ' + convert(varchar(11), @numAddedPeptideHitScores) + ' vs. ' + convert(varchar(11), @numAddedDiscScores)
		set @myError = 50025
		goto Done
	End

	-----------------------------------------------
	-- Commit changes to T_Peptides, T_Score_Sequest, etc. if we made it this far
	-----------------------------------------------------------
	-- 
	commit transaction @transName
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error committing transaction for for job ' + @jobStr
		Set @myError = 50027
		goto Done
	end

	-----------------------------------------------------------
	-- Update existing entries in T_Mass_Tags_NET that have 
	-- PNET Values different than those in #ImportedMassTags
	-----------------------------------------------------------
	--
	UPDATE T_Mass_Tags_NET
	SET PNET = IMT.GANET_Predicted, PNET_Variance = 0
	FROM #ImportedMassTags AS IMT INNER JOIN
	    T_Mass_Tags_NET AS MTN ON IMT.Mass_Tag_ID = MTN.Mass_Tag_ID
	WHERE MTN.PNET <> IMT.GANET_Predicted
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem updating PNET entries in T_Mass_Tags_NET for job ' + @jobStr
		Set @myError = 50014
		goto Done
	end

	-----------------------------------------------------------
	-- Add new entries to T_Mass_Tags_NET
	-----------------------------------------------------------
	--
	INSERT INTO T_Mass_Tags_NET (
		Mass_Tag_ID, PNET, PNET_Variance
		)
	SELECT IMT.Mass_Tag_ID, IMT.GANET_Predicted, 0 AS PNET_Variance
	FROM #ImportedMassTags AS IMT LEFT OUTER JOIN
	    T_Mass_Tags_NET AS MTN ON IMT.Mass_Tag_ID = MTN.Mass_Tag_ID
	WHERE MTN.Mass_Tag_ID IS NULL
	ORDER BY IMT.Mass_Tag_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem appending new entries to T_Mass_Tags_NET for job ' + @jobStr
		Set @myError = 50015
		goto Done
	end

	-----------------------------------------------------------
	-- Add new proteins T_Proteins
	-----------------------------------------------------------
	--
	INSERT INTO T_Proteins (Reference)
	SELECT DISTINCT PPI.Reference
	FROM #PeptideToProteinMapImported AS PPI LEFT OUTER JOIN
		 T_Proteins ON PPI.Reference = T_Proteins.Reference
	WHERE T_Proteins.Reference Is Null
	ORDER BY PPI.Reference
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem appending new entries to T_Proteins for job ' + @jobStr
		Set @myError = 50016
		goto Done
	end


	-----------------------------------------------------------
	-- Populate Ref_ID_New in #PeptideToProteinMapImported
	-----------------------------------------------------------
	--
	UPDATE #PeptideToProteinMapImported
	SET Ref_ID_New = T_Proteins.Ref_ID
	FROM #PeptideToProteinMapImported AS PPI INNER JOIN
		 T_Proteins ON PPI.Reference = T_Proteins.Reference
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem populating Ref_ID_New column in #PeptideToProteinMapImported for job ' + @jobStr
		Set @myError = 50017
		goto Done
	end


	-----------------------------------------------
    -- Check for entries in #PeptideToProteinMapImported with conflicting
    --  Cleavage_State or Terminus_State values
    -- If any conflicts are found, update Cleavage_State and Terminus_State to Null,
    --  and allow NamePeptides to populate those fields
    -----------------------------------------------
 
    UPDATE PPI
	SET Cleavage_State = NULL, Terminus_State = NULL
	FROM #PeptideToProteinMapImported AS PPI INNER JOIN
			(	SELECT DISTINCT PPI.Seq_ID, PPI.Ref_ID_New
				FROM #PeptideToProteinMapImported PPI INNER JOIN
					 #PeptideToProteinMapImported PPI_Compare ON 
						PPI.Seq_ID = PPI_Compare.Seq_ID AND 
						PPI.Ref_ID_New = PPI_Compare.Ref_ID_New
				WHERE ISNULL(PPI.Cleavage_State, 0) <> ISNULL(PPI_Compare.Cleavage_State, 0) OR
					  ISNULL(PPI.Terminus_State, 0) <> ISNULL(PPI_Compare.Terminus_State, 0)
			) AS DiffQ ON 
				PPI.Ref_ID_New = DiffQ.Ref_ID_New AND 
				PPI.Seq_ID = DiffQ.Seq_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error looking for conflicting entries in #PeptideToProteinMapImported for job ' + @jobStr
		set @myError = 50018
		goto Done
	end	
    

	-----------------------------------------------------------
	-- Add new entries to T_Mass_Tag_to_Protein_Map
	-----------------------------------------------------------
	--
	INSERT INTO T_Mass_Tag_to_Protein_Map (
		Mass_Tag_ID, Ref_ID, Cleavage_State, Terminus_State
		)
	SELECT DISTINCT PPI.Seq_ID, PPI.Ref_ID_New, PPI.Cleavage_State, PPI.Terminus_State
	FROM #PeptideToProteinMapImported As PPI LEFT OUTER JOIN 
		 T_Mass_Tag_to_Protein_Map As MTPM ON 
			PPI.Seq_ID = MTPM.Mass_Tag_ID AND
			PPI.Ref_ID_New = MTPM.Ref_ID
	WHERE MTPM.Mass_Tag_ID Is Null
	ORDER BY PPI.Seq_ID, PPI.Ref_ID_New
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem appending new entries to T_Mass_Tag_to_Protein_Map for job ' + @jobStr
		Set @myError = 50019
		goto Done
	end
	
	-----------------------------------------------------------
	-- Call ComputeMaxObsAreaByJob to populate the Max_Obs_Area_In_Job column
	-----------------------------------------------------------
	-- 
	Exec @result = ComputeMaxObsAreaByJob @JobFilterList = @JobStr

		
	-----------------------------------------------------------
	-- Update the stats in T_Mass_Tags
	-- Note that these are approximations and will get computed properly
	--  using ComputeMassTagsAnalysisCounts, which is called at the
	--  completion of UpdateMassTagsFromAvailableAnalyses
	-- This operation uses #PeptideHitStats, which was populated above
	-----------------------------------------------------------
	--
	UPDATE T_Mass_Tags
	SET Last_Affected = GetDate(), 
		Number_Of_Peptides = Number_Of_Peptides + StatsQ.Observation_Count, 
		High_Normalized_Score = CASE WHEN StatsQ.Normalized_Score_Max > High_Normalized_Score
								THEN StatsQ.Normalized_Score_Max
								ELSE High_Normalized_Score
								END
	FROM T_Mass_Tags INNER JOIN 
		#PeptideHitStats AS StatsQ ON T_Mass_Tags.Mass_Tag_ID = StatsQ.Mass_Tag_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Problem updating stats in T_Mass_Tags for job ' + @jobStr
		Set @myError = 50026
		goto Done
	end

	-----------------------------------------------------------
	-- Update Cleavage_State_Max in T_Mass_Tags
	-----------------------------------------------------------
	--
	UPDATE T_Mass_Tags
	SET Cleavage_State_Max = LookupQ.Cleavage_State_Max
	FROM T_Mass_Tags MT
	     INNER JOIN ( SELECT Seq_ID AS Mass_Tag_ID,
	                         Max(IsNull(Cleavage_State, 0)) AS Cleavage_State_Max
	                  FROM #PeptideToProteinMapImported
	                  GROUP BY Seq_ID) LookupQ
	       ON MT.Mass_Tag_ID = LookupQ.Mass_Tag_ID
	WHERE LookupQ.Cleavage_State_Max > IsNull(MT.Cleavage_State_Max, 0)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem updating Cleavage_State_Max in T_Mass_Tags for job ' + @jobStr
		Set @myError = 50028
		goto Done
	end


Done:
	-----------------------------------------------------------
	-- Update analysis job state and column RowCount_Loaded
	-----------------------------------------------------------
	--

	-- Populate @errorReturn	
	set @errorReturn = @myError
	
	-- Raise an error if no peptides were added for this job
	if (@numAddedPeptides = 0 or @numPeptidesImported = 0) AND @errorReturn = 0
		Set @errorReturn = 60000
	
	declare @state int
	if @errorReturn = 0
	Begin
		set @state = 7 -- 'Mass Tag Updated'
		set @message = Convert(varchar(12), @numAddedPeptides) + ' peptides updated into mass tags for job ' + @jobStr
	End
	else
	Begin
		set @state = 8 -- 'Mass Tag Update Failed'
		If Len(IsNull(@message, '')) = 0
			set @message = 'Error updating peptides into mass tags for job ' + @jobStr + '; ' + Convert(varchar(11), @numAddedPeptides)
	End

	--
	UPDATE T_Analysis_Description
	SET State = @state, 
		RowCount_Loaded = @numAddedPeptides
	WHERE Job = @job
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	return @errorReturn


GO
GRANT VIEW DEFINITION ON [dbo].[UpdateMassTagsFromOneAnalysis] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateMassTagsFromOneAnalysis] TO [MTS_DB_Lite]
GO
