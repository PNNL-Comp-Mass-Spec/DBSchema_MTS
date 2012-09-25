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
	@debugMode tinyint = 0,
	@IncludeDetailedResults tinyint = 0
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	declare @DBPath varchar(256)

	declare @S varchar(max)
	Declare @StartTime DateTime
	Declare @EndTime DateTime
	
	Declare @EntryID int
	Declare @Continue int
	Declare @DBName varchar(256)
	Declare @PeptideDBID int

	Declare @DBCount int = 0	
	Declare @UsageMessage varchar(512)

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
	Set @IncludeDetailedResults = IsNull(@IncludeDetailedResults, 0)
	
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
	
	CREATE TABLE #Tmp_PeptideResults (
	    Result_ID               int identity(1,1) NOT NULL,
	    Peptide_DB_ID           int NOT NULL,
	    Reference               varchar(255) NOT NULL,
	    Description             varchar(7500) NULL,
	    Cleavage_State          tinyint NULL,
	    Charge_State            smallint NULL,
	    Peptide                 varchar(850) NOT NULL,
	    Experiment              varchar(64) NULL,
	    Dataset                 varchar(128) NOT NULL,
	    Dataset_ID              int NOT NULL,
	    Instrument              varchar(64) NULL,
	    Scan_Count              int NULL,
	    Scan_First              int NULL,
	    Scan_Last               int NULL,
	    Seq_ID                  int NULL,
	    Mod_Count               int NULL,
	    Mod_Description         varchar(2048) NULL,
	    Protein_Count           int NULL,
	    Scan_Highest_Abundance  int NULL,
	    Scan_Time_Peak_Apex     real NULL,
	    Normalized_Elution_Time real NULL,
	    Peak_Area               real NULL,
	    Peak_SN_Ratio           real NULL,
	    DelM_PPM                real NULL,
	    MSGF_SpecProb           real NULL,
	    PeptideID_Highest_Abundance int NULL,
	    Entered                 datetime null default GetDate(),
	    Last_Affected           datetime null default GetDate()
	)

	CREATE NONCLUSTERED INDEX IX_Tmp_PeptideResults_PeptideDBID_DatasetID
	  ON #Tmp_PeptideResults ([Peptide_DB_ID])
	  INCLUDE ([Dataset_ID],[Seq_ID])

	CREATE NONCLUSTERED INDEX IX_Tmp_PeptideResults_PeptideDBID_SeqID
	  ON #Tmp_PeptideResults ([Peptide_DB_ID])
	  INCLUDE ([Seq_ID],[PeptideID_Highest_Abundance])


	CREATE TABLE #Tmp_BestResultsQ (
	    Dataset_ID              int NOT NULL,
	    Seq_ID                  int NULL,
	    Scan_Number             int NULL,
	    Scan_Time_Peak_Apex     real NULL,
	    Normalized_Elution_Time real NULL,
	    Peak_Area               real NULL,
	    Peak_SN_Ratio           real NULL,
	    DelM_PPM                real NULL,
	    MSGF_SpecProb           real NULL,
	    Peptide_ID              int NULL
	)

	CREATE NONCLUSTERED INDEX IX_Tmp_BestResultsQ
	  ON #Tmp_BestResultsQ (Dataset_ID, Seq_ID)
	
				
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

	IF NOT EXISTS (Select * from #Tmp_DBs_to_Search)
	Begin
		Set @message = 'No databases were found using the specified search criteria: ' + @DBsToSearch
		Set @myError = 50012
		goto Done
	End
	
	
	---------------------------------------------------
	-- Determine the filters that will be used
	-- The SQL where clause returned by ConvertListToWhereClause will look like this:
	--   Where xx In ('A','B') and Where xx Like ('C%') statements
	---------------------------------------------------

	Declare @ProteinNameWhereClause varchar(max) = ''
	Declare @PepSequenceWhereClause varchar(max) = ''
	Declare @AnalysisToolWhereClause varchar(max) = ''
	Declare @ExperimentsWhereClause varchar(max) = ''

	Exec ConvertListToWhereClause @Proteins, 'Prot.Reference', @entryListWhereClause = @ProteinNameWhereClause OUTPUT
	Exec ConvertListToWhereClause @Peptides, 'Seq.Clean_Sequence', @entryListWhereClause = @PepSequenceWhereClause OUTPUT	
	
	Exec ConvertListToWhereClause @AnalysisTool, 'TAD.Analysis_Tool', @entryListWhereClause = @AnalysisToolWhereClause OUTPUT
	Exec ConvertListToWhereClause @Experiments, 'TAD.Experiment', @entryListWhereClause = @ExperimentsWhereClause OUTPUT
	
	---------------------------------------------------
	-- Process each database in #Tmp_DBs_to_Search
	---------------------------------------------------
	
	Set @EntryID = 0
	Set @Continue = 1
	Set @DBCount = 0
	
	While @Continue = 1
	Begin
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
		Begin
			Set @DBCount = @DBCount + 1
			Set @DBPath = '[' + @DBName + ']'
			
			---------------------------------------------------
			-- Find matching peptides using the specified filters
			---------------------------------------------------
			--
			Set @S = ''
			Set @S = @S + ' INSERT INTO #Tmp_PeptideResults ('
			Set @S = @S +    ' Peptide_DB_ID,  Reference, Description, Cleavage_State, Charge_State, Peptide, '
			Set @S = @S +    ' Experiment, Dataset, Dataset_ID, Instrument, '
			Set @S = @S +    ' Scan_Count, Scan_First, Scan_Last, '
			Set @S = @S +    ' Seq_ID, Mod_Count, Mod_Description)'
			Set @S = @S + ' SELECT ' + Convert(varchar(12), @PeptideDBID) + ' AS Peptide_DB_ID, Prot.Reference, Prot.Description, PPM.Cleavage_State, Pep.Charge_State, Pep.Peptide,'
			Set @S = @S +       ' TAD.Experiment, TAD.Dataset, TAD.Dataset_ID, TAD.Instrument,'
			Set @S = @S +       ' COUNT(DISTINCT Pep.Scan_Number) AS Scan_Count,'
			Set @S = @S +       ' MIN(Pep.Scan_Number) AS Scan_First,'
			Set @S = @S +       ' MAX(Pep.Scan_Number) AS Scan_Last,'
			Set @S = @S +       ' Pep.Seq_ID, Seq.Mod_Count, Seq.Mod_Description'
			Set @S = @S + ' FROM ' + @DBPath + '.dbo.T_Peptide_to_Protein_Map PPM'
			Set @S = @S +     ' INNER JOIN ' + @DBPath + '.dbo.T_Peptides Pep ON PPM.Peptide_ID = Pep.Peptide_ID'
			Set @S = @S +     ' INNER JOIN ' + @DBPath + '.dbo.T_Proteins Prot ON PPM.Ref_ID = Prot.Ref_ID'
			Set @S = @S +     ' INNER JOIN ' + @DBPath + '.dbo.T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID'
			Set @S = @S +     ' INNER JOIN ' + @DBPath + '.dbo.T_Sequence Seq ON Pep.Seq_ID = Seq.Seq_ID'
			Set @S = @S +     ' INNER JOIN ' + @DBPath + '.dbo.T_Analysis_Description TAD ON Pep.Job = TAD.Job'
			Set @S = @S + ' WHERE ( PPM.Cleavage_State >= ' + Convert(varchar(6), @MinimumCleavageState)
			Set @S = @S +         ' AND SD.MSGF_SpecProb <= ' + Convert(varchar(24), @MSGFSpecProb) + ')'

			If @ProteinNameWhereClause <> ''
				Set @S = @S + ' AND (' + @ProteinNameWhereClause + ')'

			If @PepSequenceWhereClause <> ''
				Set @S = @S + ' AND (' + @PepSequenceWhereClause + ')'
		
			If @AnalysisToolWhereClause <> ''
				Set @S = @S + ' AND (' + @AnalysisToolWhereClause + ')'
				
			If @ExperimentsWhereClause <> ''
				Set @S = @S + ' AND (' + @ExperimentsWhereClause + ')'
			      
			Set @S = @S + ' GROUP BY Prot.Reference, Prot.Description, PPM.Cleavage_State, Pep.Charge_State, Pep.Peptide, TAD.Experiment, TAD.Dataset, TAD.Dataset_ID, TAD.Instrument,'
			Set @S = @S +          ' Pep.Seq_ID, Seq.Mod_Count, Seq.Mod_Description'
			Set @S = @S + ' ORDER BY Prot.Reference, Pep.Peptide'

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
			Values (@DBName, 'INSERT INTO #Tmp_PeptideResults', @StartTime, @EndTime)


			If @myRowCount > 0 OR @PreviewSql <> 0
			Begin
				---------------------------------------------------
				-- Obtain details on the observation with the highest peak area for each peptide 
				-- We do this in two steps to avoid table-locking issues with large databases				
				---------------------------------------------------
				
				TRUNCATE TABLE #Tmp_BestResultsQ
				
				Set @S = ''
				Set @S = @S +  ' INSERT INTO #Tmp_BestResultsQ ('
				Set @S = @S +     ' Dataset_ID, Seq_ID, Scan_Number, Scan_Time_Peak_Apex, Normalized_Elution_Time, '
				Set @S = @S +     ' Peak_Area, Peak_SN_Ratio, DelM_PPM, MSGF_SpecProb, Peptide_ID)'
				Set @S = @S +  ' SELECT Dataset_ID, Seq_ID, Scan_Number, Scan_Time_Peak_Apex, Normalized_Elution_Time,'
				Set @S = @S +         ' Peak_Area, Peak_SN_Ratio, DelM_PPM, MSGF_SpecProb, Peptide_ID'
				Set @S = @S +  ' FROM ( SELECT TAD.Dataset_ID, Pep.Seq_ID, Pep.Scan_Number, Pep.Scan_Time_Peak_Apex, Pep.GANET_Obs AS Normalized_Elution_Time,'
				Set @S = @S +                ' Pep.Peak_Area, Pep.Peak_SN_Ratio, Pep.DelM_PPM, SD.MSGF_SpecProb, Pep.Peptide_ID,'
				Set @S = @S +                ' Row_Number() OVER (Partition By TAD.Dataset_ID, Pep.Seq_ID Order By Pep.Peak_Area DESC, SD.MSGF_SpecProb) AS PeakAreaRank'
				Set @S = @S +         ' FROM  '          + @DBPath + '.dbo.T_Peptide_to_Protein_Map PPM'
				Set @S = @S +             ' INNER JOIN ' + @DBPath + '.dbo.T_Peptides Pep ON PPM.Peptide_ID = Pep.Peptide_ID'
				Set @S = @S +             ' INNER JOIN ' + @DBPath + '.dbo.T_Proteins Prot ON PPM.Ref_ID = Prot.Ref_ID'
				Set @S = @S +             ' INNER JOIN ' + @DBPath + '.dbo.T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID'
				Set @S = @S +             ' INNER JOIN ' + @DBPath + '.dbo.T_Analysis_Description TAD ON Pep.Job = TAD.Job'
				Set @S = @S +         ' WHERE Pep.Seq_ID IN (SELECT DISTINCT Seq_ID FROM #Tmp_PeptideResults WHERE Peptide_DB_ID = ' + Convert(varchar(12), @PeptideDBID) + ')'
				
				If @AnalysisToolWhereClause <> ''
					Set @S = @S + ' AND (' + @AnalysisToolWhereClause + ')'
				
				If @ExperimentsWhereClause <> ''
					Set @S = @S + ' AND (' + @ExperimentsWhereClause + ')'
				
				Set @S = @S +       ' ) LookupQ'
				Set @S = @S +  ' WHERE PeakAreaRank = 1 '
		
				Set @StartTime = GetDate()
				--
				If @PreviewSql <> 0
					Print @S
				Else
					Exec (@S)
				--
				Set @EndTime = GetDate()

				INSERT INTO #Tmp_ExecutionTimes (DBName, Step, StartTime, EndTime)
				Values (@DBName, 'Compute Stats for Best Result', @StartTime, @EndTime)
				

				Set @S = ''
				Set @S = @S + ' UPDATE Target'
				Set @S = @S + ' SET Scan_Highest_Abundance = BestResultsQ.Scan_Number,'
				Set @S = @S +     ' Scan_Time_Peak_Apex = BestResultsQ.Scan_Time_Peak_Apex,'
				Set @S = @S +     ' Normalized_Elution_Time = BestResultsQ.Normalized_Elution_Time,'
				Set @S = @S +     ' Peak_Area = BestResultsQ.Peak_Area,'
				Set @S = @S +     ' Peak_SN_Ratio = BestResultsQ.Peak_SN_Ratio,'
				Set @S = @S +     ' DelM_PPM = BestResultsQ.DelM_PPM,'
				Set @S = @S +     ' MSGF_SpecProb = BestResultsQ.MSGF_SpecProb,'
				Set @S = @S +     ' PeptideID_Highest_Abundance = BestResultsQ.Peptide_ID,'
				Set @S = @S +     ' Last_Affected = GetDate()'
				Set @S = @S + ' FROM #Tmp_PeptideResults Target'
				Set @S = @S +    ' INNER JOIN #Tmp_BestResultsQ BestResultsQ'
				Set @S = @S +      ' ON BestResultsQ.Dataset_ID = Target.Dataset_ID AND'
				Set @S = @S +         ' BestResultsQ.Seq_ID = Target.Seq_ID AND'
				Set @S = @S +         ' Target.Peptide_DB_ID = ' + Convert(varchar(12), @PeptideDBID)	 
				
				Set @StartTime = GetDate()
				--
				If @PreviewSql <> 0
					Print @S
				Else
					Exec (@S)
				--
				Set @EndTime = GetDate()

				INSERT INTO #Tmp_ExecutionTimes (DBName, Step, StartTime, EndTime)
				Values (@DBName, 'Store Stats for Best Result', @StartTime, @EndTime)
				
				
				-- Update the Protein_count column
								 
				Set @S = ''
				Set @S = @S + ' UPDATE Target'
				Set @S = @S + ' SET Protein_Count = CountQ.Protein_Count,'
				Set @S = @S +     ' Last_Affected = GetDate()'
				Set @S = @S + ' FROM #Tmp_PeptideResults Target'
				Set @S = @S +      ' INNER JOIN ( SELECT PR.Seq_ID, COUNT(DISTINCT PPM.Ref_ID) AS Protein_Count'
				Set @S = @S +                   ' FROM #Tmp_PeptideResults PR'
				Set @S = @S +                        ' INNER JOIN ' + @DBPath + '.dbo.T_Peptide_to_Protein_Map PPM ON PR.PeptideID_Highest_Abundance = PPM.Peptide_ID'
				Set @S = @S +                   ' WHERE PR.Peptide_DB_ID = ' + Convert(varchar(12), @PeptideDBID)	 
				Set @S = @S +                   ' GROUP BY PR.Seq_ID '
				Set @S = @S +                 ' ) CountQ'
				Set @S = @S +                 ' ON CountQ.Seq_ID = Target.Seq_ID AND'
				Set @S = @S +                    ' Target.Peptide_DB_ID = ' + Convert(varchar(12), @PeptideDBID)	 
						
				Set @StartTime = GetDate()
				--		 
				If @PreviewSql <> 0
					Print @S
				Else
					Exec (@S)
				--
				Set @EndTime = GetDate()

				INSERT INTO #Tmp_ExecutionTimes (DBName, Step, StartTime, EndTime)
				Values (@DBName, 'Compute Protein_Count for each Seq_ID', @StartTime, @EndTime)
			
			End
			
		End
	End
	
	If @PreviewSql = 0
	Begin
		------------------------------------------------------------
		-- Report the best scan for each charge state of each peptide
		------------------------------------------------------------
		
		Set @StartTime = GetDate()
		--		 
		SELECT TotalsQ.*,
		       FilterQ.Experiment,
		       FilterQ.Dataset,
		       FilterQ.Dataset_ID,
		       FilterQ.Instrument,
		       FilterQ.Scan_First,
		       FilterQ.Scan_Last,
		       FilterQ.Scan_Highest_Abundance,
		       FilterQ.Scan_Time_Peak_Apex,
		       FilterQ.Normalized_Elution_Time,
		       FilterQ.Peak_Area,
		       FilterQ.Peak_SN_Ratio,
		       FilterQ.DelM_PPM,
		       FilterQ.MSGF_SpecProb,
		       FilterQ.Peptide_DB_ID,
		       FilterQ.Peptide_DB_Name,
		       FilterQ.PeptideID_Highest_Abundance
		FROM ( SELECT PR.Reference,
		              PR.Description,
		            PR.Cleavage_State,
		              PR.Charge_State,
		              PR.Peptide,
		              PR.Experiment,
		              PR.Dataset,
		              PR.Dataset_ID,
		              PR.Instrument,
		              PR.Scan_Count,
		              PR.Scan_First,
		              PR.Scan_Last,
		              PR.Seq_ID,
		              PR.Protein_Count,
		              PR.Scan_Highest_Abundance,
		              PR.Scan_Time_Peak_Apex,
		              PR.Normalized_Elution_Time,
		              PR.Peak_Area,
		              PR.Peak_SN_Ratio,
		              PR.DelM_PPM,
		              PR.MSGF_SpecProb,
		              PR.Peptide_DB_ID,
		              PTDBs.Peptide_DB_Name,
		              PR.PeptideID_Highest_Abundance,
		       Row_Number() OVER ( PARTITION BY PR.Reference, PR.Seq_ID ORDER BY PR.Peak_Area DESC, IsNull(PR.MSGF_SpecProb, 1) ) AS PeakAreaRank
		       FROM #Tmp_PeptideResults PR
		            INNER JOIN MT_Main.dbo.V_MTS_PT_DBs PTDBs
		              ON PR.Peptide_DB_ID = PTDBs.Peptide_DB_ID 
		     ) FilterQ
		     INNER JOIN ( SELECT PR.Reference,
		                         Min(PR.Description) As Description,
		                         PR.Cleavage_State,
		                         PR.Charge_State,
		                         PR.Peptide,
		                         Count(Distinct PR.Dataset_ID) AS Dataset_Count,
		                         Max(PR.Scan_Count) AS Scan_Count_Max,
		                         PR.Seq_ID,
		                         PR.Mod_Count, 
		                         PR.Mod_Description,
		                         PR.Protein_Count,
		                         Avg(PR.Normalized_Elution_Time) AS Normalized_Elution_Time_Avg,
		                         Avg(PR.Peak_Area) AS Peak_Area_Avg,
		                         Avg(PR.Peak_SN_Ratio) AS Peak_SN_Ratio_Avg,
		                         Avg(PR.DelM_PPM) AS DelM_PPM_Avg,
		                         Min(PR.MSGF_SpecProb) AS MSGF_SpecProb_Minimum
		                  FROM #Tmp_PeptideResults PR
		                       INNER JOIN MT_Main.dbo.V_MTS_PT_DBs PTDBs
		                         ON PR.Peptide_DB_ID = PTDBs.Peptide_DB_ID		                       
		                  GROUP BY PR.Reference, PR.Cleavage_State, PR.Charge_State, PR.Peptide,
		                           PR.Seq_ID, PR.Protein_Count, PR.Mod_Count, PR.Mod_Description
		       ) TotalsQ
		       ON FilterQ.Reference = TotalsQ.Reference AND
		          FilterQ.Seq_ID = TotalsQ.Seq_ID AND
		          FilterQ.Charge_State = TotalsQ.Charge_State
		WHERE PeakAreaRank = 1
		ORDER BY TotalsQ.Reference, TotalsQ.Scan_Count_Max Desc, TotalsQ.Seq_ID
		--	
		-- Cache the row count, which is used by @usageMessage below
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		Set @EndTime = GetDate()

		INSERT INTO #Tmp_ExecutionTimes (DBName, Step, StartTime, EndTime)
		Values (@DBName, 'Report Stats for Best Result', @StartTime, @EndTime)
				
		
		If @IncludeDetailedResults <> 0
		Begin
			-- Report the detailed results
			
			Set @StartTime = GetDate()
			--		 
			SELECT PR.Reference,
				PR.Description,
				PR.Cleavage_State,
				PR.Charge_State,
				PR.Peptide,
				PR.Experiment,
				PR.Dataset,
				PR.Dataset_ID,
				PR.Instrument,
				PR.Scan_Count,
				PR.Scan_First,
				PR.Scan_Last,
				PR.Seq_ID,
				PR.Mod_Count, 
				PR.Mod_Description,
				PR.Protein_Count,
				PR.Scan_Highest_Abundance,
				PR.Scan_Time_Peak_Apex,
				PR.Normalized_Elution_Time,
				PR.Peak_Area,
				PR.Peak_SN_Ratio,
				PR.DelM_PPM,
				PR.MSGF_SpecProb,
				PR.Peptide_DB_ID,
				PTDBs.Peptide_DB_Name,
				PR.PeptideID_Highest_Abundance
			FROM #Tmp_PeptideResults PR
				INNER JOIN MT_Main.dbo.V_MTS_PT_DBs PTDBs
					ON PR.Peptide_DB_ID = PTDBs.Peptide_DB_ID
			ORDER BY PR.Reference, PR.Peptide, PR.Peak_Area Desc
			--
			Set @EndTime = GetDate()
			
			INSERT INTO #Tmp_ExecutionTimes (DBName, Step, StartTime, EndTime)
			Values (@DBName, 'Report detailed results', @StartTime, @EndTime)
					
		End
		
	End

	if @debugMode <> 0
	Begin
		SELECT *, DateDiff(millisecond, StartTime, EndTime) / 1000.0 as Execution_Time_Sec
		FROM #Tmp_ExecutionTimes
		ORDER BY Entry_ID
	End
	
	
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' results; ' + Convert(varchar(9), @DBCount) + ' DB'
	If @DBCount = 1
		Set @UsageMessage = @UsageMessage + ' searched'
	Else
		Set @UsageMessage = @UsageMessage + 's searched'
	
	If @DBCount > 0
		Set @DBName = 'Multiple'
		
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
