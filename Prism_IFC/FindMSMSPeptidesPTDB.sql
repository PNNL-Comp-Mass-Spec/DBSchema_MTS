/****** Object:  StoredProcedure [dbo].[FindMSMSPeptidesPTDB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE dbo.FindMSMSPeptidesPTDB
/****************************************************
**
**	Desc: 
**		Searches one or more PT databases to find the confidently identified peptides for one or more proteins.
**
**		NOTE: For performance reasons, the DBs to search must reside on this server
**		We tried allowing for cross-server querying, but the performance degraded dramatically due to the complexity of the queries
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @DBsToSearch			-- Comma separated list of Peptide DB names or list of DB name match criteria containing a wildcard character(%)
**							-- Example: 'PT_Human_sp_A197, PT_Human_sp_A233, PT_Human_sp_A260'
**							--      or: 'PT_Human_sp%'
**							--      or: '%Human%, %Mouse%'
**    @Proteins				-- Optional Filter: Comma separated list of proteins or list of protein match criteria containing a wildcard character(%)
**							-- Example: 'ProteinA, ProteinB, ProteinC'
**							--      or: 'ProteinA%'
**							--      or: 'ProteinA, ProteinB, ProteinC%'
**    @Peptides				-- Optional Filter: Comma separated list of Peptides or list of Peptide match criteria containing a wildcard character(%)
**							--                  Note: Do not include any modification symbols or any prefix or suffix letters
**							-- Example: 'PeptideA, PeptideB, PeptideC'
**							--      or: 'PeptideA%'
**							--      or: 'PeptideA, PeptideB, PeptideC%'
**	  @MinimumCleavageState -- Cleavage state filter; 0 for all; 1 for partially or fully tryptic; 2 for fully-tryptic only
**    @MSGFSpecProb         -- MSGF Spectral Probability Threshold; e.g. 1E-10
**	  @AnalysisTool			-- Optional Filter: Comma separated list of analysis tools to filter on; may contain a wildcard character(%)
**							-- Example: 'Sequest, Sequest_DTARefinery'
**							--      or: 'Sequest%'
**							--      or: 'Sequest%, MSGFDB%'
**	  @Experiments			-- Optional Filter: Comma separated list of experiments or list of experiment match criteria containing a wildcard character(%)
**							-- Example: 'ExpA, ExpB, ExpC'
**							--      or: 'ExpA%'
**							--      or: 'ExpA, ExpB, ExpC%'
**	  @message				-- Status/error message output
**
**	Auth:	mem
**	Date:	07/11/2012 mem - Initial version
**			01/09/2013 mem - Added column Peak_SN_Ratio_Max
**			05/10/2013 mem - Now calling FindMSMSPeptidesPTDBWork with sets of proteins
**							 Removed the option to return detailed results
**
*****************************************************/
(
	@DBsToSearch varchar(max) = '',				-- Comma separated list, % wildcard character allowed; will only search DBs that reside on this server
	@IncludeFrozenAndUnusedDBs tinyint = 0,		-- 0 to ignore Frozen/Unused Peptide DBs; 1 to include them (Frozen have State=3, Unused have State=10)
	@Proteins varchar(max) = '',				-- Comma separated list, % wildcard character allowed
	@Peptides varchar(max) = '',				-- Comma separated list, % wildcard character allowed; Do not include any modification symbols or any prefix or suffix letters since this is compared against T_Sequence.Clean_Sequence
	@MinimumCleavageState tinyint = 1,			-- 0 means any peptide; 1 means partially or fully tryptic, 2 means fully tryptic
	@MSGFSpecProb float = 1E-10,	
	@AnalysisTool varchar(64) = '',				-- Comma separated list, % wildcard character allowed
	@Experiments varchar(max) = '',				-- Comma separated list, % wildcard character allowed
	@message varchar(512) = '' output,
	@previewSql tinyint = 0,					-- Preview the Sql used
	@debugMode tinyint = 0	
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	declare @S varchar(max)
	Declare @StartTime DateTime
	Declare @EndTime DateTime

	Declare @EntryID int
	Declare @Continue int
	Declare @PeptideDBID int
	Declare @DBName varchar(256)
	Declare @DBPath varchar(256)

	Declare @DBCount int = 0	
	
	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------
	--
	Set @DBsToSearch = IsNull(@DBsToSearch, '')
	Set @IncludeFrozenAndUnusedDBs = IsNull(@IncludeFrozenAndUnusedDBs, 0)
	Set @Proteins = IsNull(@Proteins, '')
	Set @Peptides = IsNull(@Peptides, '')
	Set @MinimumCleavageState = IsNull(@MinimumCleavageState, 1)
	Set @MSGFSpecProb = IsNull(@MSGFSpecProb, 1E-10)
	Set @AnalysisTool = IsNull(@AnalysisTool, '')
	Set @Experiments = IsNull(@Experiments, '')	
	Set @message = ''
	Set @previewSql = IsNull(@previewSql, 0)
	Set @debugMode = IsNull(@debugMode, 0)
	
	If LTrim(RTrim(@DBsToSearch)) = ''
	Begin
		Set @message = '@DBsToSearch cannot be empty; unable to continue'
		Set @myError = 50000
		goto Done
	End
	
	If LTrim(RTrim(@Proteins)) = '' And LTrim(RTrim(@Peptides)) = ''
	Begin
		Set @message = 'Must define one or more proteins, and/or one or more peptides to search for using @Proteins and/or @Peptides'
		Set @myError = 50001
		goto Done
	End
	
	---------------------------------------------------
	-- Create some temporary tables
	---------------------------------------------------
	
	CREATE TABLE #Tmp_DBs_to_Search (
	    Entry_ID                int identity(1,1) NOT NULL,
	    Peptide_DB_Name         varchar(256) NOT NULL,
	    State_ID                int NOT NULL,
	    Peptide_DB_ID           int NOT NULL
	)
	
	CREATE TABLE #Tmp_ProteinFilter (
		Reference varchar(255) NOT NULL,
		Entry_ID int identity(1,1) NOT NULL
	)
	
	CREATE UNIQUE INDEX #IX_Tmp_ProteinFilter_Referencxe ON #Tmp_ProteinFilter (Reference)
	CREATE UNIQUE CLUSTERED index #IX_Tmp_ProteinFilter_EntryID ON #Tmp_ProteinFilter (Entry_ID)
	
	CREATE TABLE #Tmp_PeptideFilter (
		CleanSequence varchar(850) NOT NULL,
		Entry_ID int identity(1,1) NOT NULL
	)
	
	CREATE UNIQUE INDEX #IX_Tmp_PeptideFilter_Sequence ON #Tmp_PeptideFilter (CleanSequence)
	CREATE UNIQUE CLUSTERED index #IX_Tmp_PeptideFilter_EntryID ON #Tmp_PeptideFilter (Entry_ID)


	CREATE TABLE #Tmp_ProteinFilterCurrent (
		Reference varchar(255) NOT NULL
	)
	
	CREATE UNIQUE CLUSTERED INDEX #IX_Tmp_ProteinFilterCurrent ON #Tmp_ProteinFilterCurrent (Reference)
	
	CREATE TABLE #Tmp_PeptideFilterCurrent (
		CleanSequence varchar(850) NOT NULL
	)
	
	CREATE UNIQUE CLUSTERED INDEX #IX_Tmp_PeptideFilterCurrent ON #Tmp_PeptideFilterCurrent (CleanSequence)

	CREATE TABLE #Tmp_ResultsTable (
		Ref_ID int NOT NULL,
		Reference varchar(255) NULL,
		Description varchar(7500) NULL,
		Seq_ID int NULL,
		Charge_State smallint NULL,
		Cleavage_State tinyint NULL,
		Peptide varchar(850) NOT NULL,
		Dataset_Count int NULL,
		Total_PSMs int NULL,
		Mod_Count int NULL,
		Mod_Description varchar(2048) NULL,
		Protein_Count int NULL,
		Normalized_Elution_Time_Avg float NULL,
		Peak_Area_Avg float NULL,
		Peak_SN_Ratio_Avg float NULL,
		Peak_SN_Ratio_Max real NULL,
		DelM_PPM_Avg float NULL,
		MSGF_SpecProb_Minimum real NULL,
		Experiment varchar(64) NULL,
		Dataset varchar(128) NULL,
		Dataset_ID int NULL,
		Instrument varchar(64) NULL,
		Scan_Highest_Abundance int NULL,
		Scan_Time_Peak_Apex real NULL,
		Normalized_Elution_Time real NULL,
		Peak_Area real NULL,
		Peak_SN_Ratio real NULL,
		DelM_PPM real NULL,
		MSGF_SpecProb real NULL,
		Peptide_DB_ID int NOT NULL,
		PeptideID_Highest_Abundance int NULL
	)
	
	CREATE NONCLUSTERED INDEX #IX_Tmp_ResultsTable_PeptideDBID_SeqID
	  ON #Tmp_ResultsTable (Peptide_DB_ID)
	  INCLUDE (Seq_ID)

	CREATE NONCLUSTERED INDEX #IX_Tmp_ResultsTable_PeptideDBID_DatasetID
	  ON #Tmp_ResultsTable (Peptide_DB_ID)
	  INCLUDE (Dataset_ID)
		
	CREATE TABLE #Tmp_PeptideResultsForBatch (
	    Ref_ID                      int NOT NULL,
	    Seq_ID                      int NOT NULL,
	    Charge_State                smallint NULL,
	    Cleavage_State              tinyint NULL,
	    Peptide                     varchar(850) NULL,
	  Dataset_Count               int NULL,
	    Total_PSMs                  int NULL,
	    Protein_Count               int NULL,
	    Normalized_Elution_Time_Avg real NULL,
	    Peak_Area_Avg               real NULL,
	    Peak_SN_Ratio_Avg           real NULL,
	    Peak_SN_Ratio_Max           real NULL,
	    DelM_PPM_Avg                real NULL,
	    MSGF_SpecProb_Minimum       real NULL,
	    Dataset_ID                  int NULL,
	    Scan_Highest_Abundance      int NULL,
	    Scan_Time_Peak_Apex         real NULL,
	    Normalized_Elution_Time     real NULL,
	    Peak_Area                   real NULL,
	    Peak_SN_Ratio               real NULL,
	    DelM_PPM                    real NULL,
	    MSGF_SpecProb               real NULL,
	    PeptideID_Highest_Abundance int NULL,
	    Entered                     datetime NULL DEFAULT GetDate()
	)
	
	CREATE NONCLUSTERED INDEX #IX_Tmp_PeptideResultsForBatch_Ref_ID
	  ON #Tmp_PeptideResultsForBatch (Ref_ID)
	  INCLUDE (Seq_ID)

	CREATE NONCLUSTERED INDEX #IX_Tmp_PeptideResultsForBatch_SeqID
	  ON #Tmp_PeptideResultsForBatch (Seq_ID)

	CREATE NONCLUSTERED INDEX #IX_Tmp_PeptideResultsForBatch_Dataset_Count
	  ON #Tmp_PeptideResultsForBatch (Dataset_Count)
	  INCLUDE (Seq_ID)
					
	CREATE TABLE #Tmp_ExecutionTimes (
	    Entry_ID  int IDENTITY ( 1, 1 ) NOT NULL,
	    DBName    varchar(256) NULL,
	    Step      varchar(256) NULL,
	    StartTime datetime NULL,
	    EndTime   datetime NULL
	)
		
	---------------------------------------------------
	-- Determine the databases that will be searched
	-- The SQL where clause returned by ConvertListToWhereClause will look like this:
	--   Where xx In ('A','B') and Where xx Like ('C%') statements
	---------------------------------------------------

	Declare @DBNameWhereClause varchar(max)

	Set @DBNameWhereClause = ''
	Exec ConvertListToWhereClause @DBsToSearch, 'PDB_Name', @entryListWhereClause = @DBNameWhereClause OUTPUT

	---------------------------------------------------
	-- Find the location of the databases
	---------------------------------------------------
	
	Set @S = ''
	Set @S = @S + ' INSERT INTO #Tmp_DBs_to_Search (Peptide_DB_Name, State_ID, Peptide_DB_ID)'
	Set @S = @S + ' SELECT PDB_Name, PDB_State, PDB_ID'
	Set @S = @S + ' FROM MT_Main.dbo.T_Peptide_Database_List'
	If @IncludeFrozenAndUnusedDBs <> 0
		Set @S = @S + ' WHERE PDB_State < 15)'
	Else
		Set @S = @S + ' WHERE (PDB_State < 10 And PDB_State <> 3)'
	
	If @DBNameWhereClause <> ''
		Set @S = @S + ' AND (' + @DBNameWhereClause + ')'

	If @PreviewSql <> 0
		Print @S
		
	Exec (@S)		
	
	If @PreviewSql <> 0
		SELECT * FROM #Tmp_DBs_to_Search

	SELECT @DBCount = COUNT(*)
	FROM #Tmp_DBs_to_Search

	IF @DBCount = 0
	Begin
		Set @message = 'No databases were found using the specified search criteria: ' + @DBsToSearch
		Set @myError = 50012
		goto Done
	End
	
	---------------------------------------------------
	-- Populate #Tmp_ProteinFilter and #Tmp_PeptideFilter using @Proteins and @Peptides
	---------------------------------------------------
	
	INSERT INTO #Tmp_ProteinFilter (Reference)
	SELECT Distinct Value
	FROM dbo.udfParseDelimitedList(@Proteins, ',')
	
	
	INSERT INTO #Tmp_PeptideFilter (CleanSequence)
	SELECT Distinct Value
	FROM dbo.udfParseDelimitedList(@Peptides, ',')
	
	If Not Exists (SELECT * FROM #Tmp_ProteinFilter) And Not Exists (SELECT * FROM #Tmp_PeptideFilter)
	Begin
		Set @message = 'Must define one or more proteins, and/or one or more peptides to search for using @Proteins and/or @Peptides'
		Set @myError = 50001
		goto Done
	End
	
		
	---------------------------------------------------
	-- Determine the filters that will be used
	-- The SQL where clause returned by ConvertListToWhereClause will look like this:
	--   Where xx In ('A','B') and Where xx Like ('C%') statements
	---------------------------------------------------

	Declare @AnalysisToolWhereClause varchar(max) = ''
	Declare @ExperimentsWhereClause varchar(max) = ''

	Exec ConvertListToWhereClause @AnalysisTool, 'TAD.Analysis_Tool', @entryListWhereClause = @AnalysisToolWhereClause OUTPUT
	Exec ConvertListToWhereClause @Experiments, 'TAD.Experiment', @entryListWhereClause = @ExperimentsWhereClause OUTPUT
	
	
	---------------------------------------------------
	-- Process 10 proteins at a time from @Proteins
	-- Process 50 peptides at a time from @Peptides
	---------------------------------------------------

	Declare @ProteinChunkSize int = 10
	Declare @PeptideChunkSize int = 50
		
	Declare @ProteinFilterIDMax int
	Declare @PeptideFilterIDMax int

	Declare @ProteinFilterIDStart int
	Declare @PeptideFilterIDStart int

	
	If Exists (Select * From #Tmp_ProteinFilter)
		SELECT @ProteinFilterIDMax = Max(Entry_ID) FROM #Tmp_ProteinFilter
	Else
		Set @ProteinFilterIDMax = 1
	
	If Exists (Select * From #Tmp_PeptideFilter)
		SELECT @PeptideFilterIDMax = Max(Entry_ID) FROM #Tmp_PeptideFilter
	Else
		Set @PeptideFilterIDMax = 1
	
	
	
	---------------------------------------------------
	-- Process each database in #Tmp_DBs_to_Search
	---------------------------------------------------
	
	Set @EntryID = 0
	Set @Continue = 1
	
	While @Continue = 1
	Begin -- <a>
	
		SELECT TOP 1 @EntryID = Entry_ID,
					 @DBName = Peptide_DB_Name,
					 @PeptideDBID = Peptide_DB_ID
		FROM #Tmp_DBs_to_Search
		WHERE Entry_ID > @EntryID
		ORDER BY Entry_ID
		--	
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowcount = 0
			Set @Continue = 0
		Else
		Begin -- <b>
			Set @DBPath = '[' + @DBName + ']'
	
			
			Set @ProteinFilterIDStart = 1
			While @ProteinFilterIDStart <= @ProteinFilterIDMax
			Begin
				TRUNCATE TABLE #Tmp_ProteinFilterCurrent
				
				INSERT INTO #Tmp_ProteinFilterCurrent (Reference)
				SELECT Reference
				FROM #Tmp_ProteinFilter
				WHERE Entry_ID >= @ProteinFilterIDStart And Entry_ID < @ProteinFilterIDStart + @ProteinChunkSize
				
				If @DebugMode = 1
				Begin
					If Exists (Select * From #Tmp_ProteinFilter)
						Print 'Processing proteins ' + Convert(varchar(12), @ProteinFilterIDStart) + ' to ' + Convert(varchar(12), @ProteinFilterIDStart + @ProteinChunkSize - 1)
					Else
						Print 'Not using a protein filter'
				End
					
				Set @PeptideFilterIDStart = 1
				While @PeptideFilterIDStart <= @PeptideFilterIDMax
				Begin

					TRUNCATE TABLE #Tmp_PeptideFilterCurrent
					
					INSERT INTO #Tmp_PeptideFilterCurrent (CleanSequence)
					SELECT CleanSequence
					FROM #Tmp_PeptideFilter
					WHERE Entry_ID >= @PeptideFilterIDStart And Entry_ID < @PeptideFilterIDStart + @PeptideChunkSize

					If @DebugMode = 1
					Begin
						If Exists (Select * From #Tmp_PeptideFilter)
							Print 'Processing peptides ' + Convert(varchar(12), @PeptideFilterIDStart) + ' to ' + Convert(varchar(12), @PeptideFilterIDStart + @PeptideChunkSize - 1)
						Else
							Print 'Not using a peptide filter'
					End
				
					TRUNCATE TABLE #Tmp_PeptideResultsForBatch
					
					---------------------------------------------------
					-- Extract the data for these proteins/peptides	
					---------------------------------------------------
					--
					exec FindMSMSPeptidesPTDBWork  @DBPath, @MinimumCleavageState, @MSGFSpecProb, @AnalysisToolWhereClause, @ExperimentsWhereClause, @previewSql, @debugMode, @message output
				
					---------------------------------------------------
					-- Append new rows to the master results table
					---------------------------------------------------
					--
					INSERT INTO #Tmp_ResultsTable (
						Peptide_DB_ID, 
						Ref_ID, Seq_ID, Cleavage_State, Charge_State, 
						Peptide, Dataset_Count, Total_PSMs, 
						Protein_Count, Normalized_Elution_Time_Avg, 
						Peak_Area_Avg, Peak_SN_Ratio_Avg, Peak_SN_Ratio_Max, 
						DelM_PPM_Avg, MSGF_SpecProb_Minimum, 
						Dataset_ID, Scan_Highest_Abundance, Scan_Time_Peak_Apex, 
						Normalized_Elution_Time, Peak_Area, Peak_SN_Ratio, DelM_PPM, 
						MSGF_SpecProb, PeptideID_Highest_Abundance
					)
					SELECT @PeptideDBID, 
					    S.Ref_ID, S.Seq_ID, S.Cleavage_State, S.Charge_State,
						S.Peptide, S.Dataset_Count, S.Total_PSMs,
						S.Protein_Count, S.Normalized_Elution_Time_Avg,
						S.Peak_Area_Avg, S.Peak_SN_Ratio_Avg, S.Peak_SN_Ratio_Max,
						S.DelM_PPM_Avg, S.MSGF_SpecProb_Minimum,
						S.Dataset_ID, S.Scan_Highest_Abundance, S.Scan_Time_Peak_Apex,
						S.Normalized_Elution_Time, S.Peak_Area, S.Peak_SN_Ratio, S.DelM_PPM,
						S.MSGF_SpecProb, S.PeptideID_Highest_Abundance
					FROM #Tmp_PeptideResultsForBatch AS S
						LEFT OUTER JOIN #Tmp_ResultsTable AS Target
						ON Target.Peptide_DB_ID = @PeptideDBID AND
						   Target.Ref_ID = S.Ref_ID AND
						   Target.Seq_ID = S.Seq_ID 
					WHERE NOT S.Dataset_Count IS NULL AND Target.Seq_ID IS NULL
					
					If @PreviewSql=1
						Print 'INSERT INTO #Tmp_ResultsTable (...) SELECT ... FROM #Tmp_PeptideResultsForBatch AS S LEFT OUTER JOIN #Tmp_ResultsTable AS Target ON Target.Peptide_DB_ID = @PeptideDBID AND Target.Ref_ID = S.Ref_ID AND Target.Seq_ID = S.Seq_ID WHERE NOT S.Dataset_Count IS NULL AND Target.Seq_ID IS NULL'
	
	
					Set @PeptideFilterIDStart = @PeptideFilterIDStart + @PeptideChunkSize
	
				End

				Set @ProteinFilterIDStart = @ProteinFilterIDStart + @ProteinChunkSize
				
			End		
	
			---------------------------------------------------
			-- All proteins have been processed for this Peptide DB
			---------------------------------------------------
			--
			-- Update Dataset info in the Master Results Table
			--
			Set @S = ''
			Set @S = @S + ' UPDATE Target'
			Set @S = @S + ' SET Experiment = SourceQ.Experiment,'
			Set @S = @S +     ' Dataset = SourceQ.Dataset,'
			Set @S = @S +     ' Instrument = SourceQ.Instrument'
			Set @S = @S + ' FROM #Tmp_ResultsTable Target'
			Set @S = @S +      ' INNER JOIN ( SELECT TAD.Dataset_ID,'
			Set @S = @S +                          ' TAD.Experiment,'
			Set @S = @S +                          ' TAD.Dataset,'
			Set @S = @S +                          ' TAD.Instrument'
			Set @S = @S +                   ' FROM ' + @DBPath + '.dbo.T_Analysis_Description TAD'
			Set @S = @S +                   ' WHERE Dataset_ID IN ( SELECT DISTINCT Dataset_ID'
			Set @S = @S +                                         ' FROM #Tmp_ResultsTable'
			Set @S = @S +                                         ' WHERE Peptide_DB_ID = ' + Convert(varchar(12), @PeptideDBID) + ' ) '
			Set @S = @S +                  ' ) SourceQ'
			Set @S = @S +           ' ON Target.Dataset_ID = SourceQ.Dataset_ID'
			Set @S = @S + ' WHERE Target.Peptide_DB_ID = ' + Convert(varchar(12), @PeptideDBID) 
			Set @S = @S +       ' AND Target.Dataset IS NULL'

			Set @StartTime = GetDate()
			--
			If @PreviewSql <> 0
				Print @S
			Else
				Exec (@S)
			--	
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			Set @EndTime = GetDate()

			INSERT INTO #Tmp_ExecutionTimes (DBName, Step, StartTime, EndTime)
			Values (@DBPath, 'Update dataset names', @StartTime, @EndTime)

			--
			-- Update Sequence info in the Master Results Table
			--
			Set @S = ''
			Set @S = @S + ' UPDATE Target'
			Set @S = @S + ' SET Mod_Count = Seq.Mod_Count, '
			Set @S = @S +     ' Mod_Description = Seq.Mod_Description'
			Set @S = @S + ' FROM #Tmp_ResultsTable Target'
			Set @S = @S +      ' INNER JOIN ' + @DBPath + '.dbo.T_Sequence Seq ON Target.Seq_ID = Seq.Seq_ID'
			Set @S = @S +      ' INNER JOIN ' + @DBPath + '.dbo.T_Peptides Pep ON Target.PeptideID_Highest_Abundance = Pep.Peptide_ID AND Seq.Seq_ID = Pep.Seq_ID'
			Set @S = @S + ' WHERE Target.Peptide_DB_ID = ' + Convert(varchar(12), @PeptideDBID)
			Set @S = @S +       ' AND Target.Mod_Count Is Null'

			Set @StartTime = GetDate()
			--
			If @PreviewSql <> 0
				Print @S
			Else
				Exec (@S)
			--	
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			Set @EndTime = GetDate()

			INSERT INTO #Tmp_ExecutionTimes (DBName, Step, StartTime, EndTime)
			Values (@DBPath, 'Update Sequence info', @StartTime, @EndTime)
						
			--
			-- Update Protein Info in the Master Results Table
			--
			Set @S = ''
			Set @S = @S + ' UPDATE Target'
			Set @S = @S + ' SET Reference = Prot.Reference, '
			Set @S = @S +     ' Description = Prot.Description'
			Set @S = @S + ' FROM #Tmp_ResultsTable Target'
			Set @S = @S +      ' INNER JOIN ' + @DBPath + '.dbo.T_Peptide_to_Protein_Map PPM ON Target.PeptideID_Highest_Abundance = PPM.Peptide_ID'
			Set @S = @S +      ' INNER JOIN ' + @DBPath + '.dbo.T_Proteins Prot ON PPM.Ref_ID = Prot.Ref_ID AND Target.Ref_ID = Prot.Ref_ID'
			Set @S = @S + ' WHERE Target.Peptide_DB_ID = ' + Convert(varchar(12), @PeptideDBID)
			Set @S = @S +       ' AND Target.Reference Is Null'

			Set @StartTime = GetDate()
			--
			If @PreviewSql <> 0
				Print @S
			Else
				Exec (@S)
			--	
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			Set @EndTime = GetDate()

			INSERT INTO #Tmp_ExecutionTimes (DBName, Step, StartTime, EndTime)
			Values (@DBPath, 'Update Protein info (part 1)', @StartTime, @EndTime)
			
			
			
			-- Protein Info might still be null
			-- Use a different method to update any remaining proteins
			--
			Set @S = ''
			Set @S = @S + ' UPDATE Target'
			Set @S = @S + ' SET Reference = SourceQ.Reference,'
			Set @S = @S +     ' Description = SourceQ.Description'
			Set @S = @S + ' FROM #Tmp_ResultsTable Target'
			Set @S = @S +      ' INNER JOIN ( SELECT DISTINCT Ref_ID, Reference, Description'
			Set @S = @S +                   ' FROM ' + @DBPath + '.dbo.T_Proteins Prot'
			Set @S = @S +                   ' WHERE NOT Reference Is Null AND '
			Set @S = @S +                         ' Ref_ID IN ( SELECT DISTINCT Ref_ID'
			Set @S = @S +                                     ' FROM #Tmp_ResultsTable'
			Set @S = @S +                                     ' WHERE Peptide_DB_ID = ' + Convert(varchar(12), @PeptideDBID)
			Set @S = @S +                                           ' AND Reference Is Null'
			Set @S = @S +                                 + ' ) '
			Set @S = @S +                  ' ) SourceQ'
			Set @S = @S +           ' ON Target.Ref_ID = SourceQ.Ref_ID'
			Set @S = @S + ' WHERE Target.Peptide_DB_ID = ' + Convert(varchar(12), @PeptideDBID) 
			Set @S = @S +       ' AND Target.Reference IS NULL'

			Set @StartTime = GetDate()
			--
			If @PreviewSql <> 0
				Print @S
			Else
				Exec (@S)
			--	
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			Set @EndTime = GetDate()

			INSERT INTO #Tmp_ExecutionTimes (DBName, Step, StartTime, EndTime)
			Values (@DBPath, 'Update Protein info (part 2)', @StartTime, @EndTime)
			
		End -- </b>
	End -- </a>
	
	
	---------------------------------------------------
	-- Report the results
	---------------------------------------------------
	--
	SELECT R.*,
	       PTDBs.Peptide_DB_Name
	FROM #Tmp_ResultsTable R
	     INNER JOIN MT_Main.dbo.V_MTS_PT_DBs PTDBs
	       ON R.Peptide_DB_ID = PTDBs.Peptide_DB_ID
	ORDER BY R.Reference, R.Peptide, R.Peak_Area DESC
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount

	if @debugMode <> 0
	Begin
		SELECT *, DateDiff(millisecond, StartTime, EndTime) / 1000.0 as Execution_Time_Sec
		FROM #Tmp_ExecutionTimes
		ORDER BY Entry_ID
	End

	---------------------------------------------------
	-- Log usage
	---------------------------------------------------

	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' results; ' + Convert(varchar(9), @DBCount) + ' DB'
	If @DBCount = 1
		Set @UsageMessage = @UsageMessage + ' searched'
	Else
		Set @UsageMessage = @UsageMessage + 's searched'
	
	If @DBCount > 1
		Set @DBName = 'Multiple'
	Else
		SELECT TOP 1 @DBName = Peptide_DB_Name
		FROM #Tmp_DBs_to_Search		
		
	If @previewSql <> 0
		Print @UsageMessage
	Else
		Exec PostUsageLogEntry 'FindMSMSPeptidesPTDB', @DBName, @UsageMessage
	
Done:
	If @myError <> 0
	Begin
		If @previewSql <> 0
			Select @myError as Error_Code, @Message as Error_Message
		Else
			Print @Message
	End

	return @myError


GO
GRANT EXECUTE ON [dbo].[FindMSMSPeptidesPTDB] TO [DMS_SP_User] AS [dbo]
GO
