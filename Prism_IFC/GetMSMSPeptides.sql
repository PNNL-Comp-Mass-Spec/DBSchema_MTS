/****** Object:  StoredProcedure [dbo].[GetMSMSPeptides] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetMSMSPeptides
/****************************************************
**
**	Desc: 
**		Returns list of peptides identified by Sequest or X!Tandem for the given jobs, dataset(s), and/or experiment(s)
**		Can read the data from a PT or an MT database, and that DB need not reside on this server; 
**		  MTS_Master will be called to determine the location of this DB in MTS
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @DBName				-- Mass tag database or Peptide database name
**	  @AnalysisTool			-- Required: Must be Sequest or XTandem
**	  @Jobs					-- Optional Filter: Comma separated list of job numbers
**	  @Datasets				-- Optional Filter: Comma separated list of datasets or list of dataset match criteria containing a wildcard character(%)
**							-- Example: 'DatasetA, DatasetB, DatasetC'
**							--      or: 'DatasetA%'
**							--      or: 'DatasetA, DatasetB, DatasetC%'
**							--      or: 'DatasetA, DatasetB%, DatasetC'
**	  @Experiments			-- Optional Filter: Comma separated list of experiments or list of experiment match criteria containing a wildcard character(%)
**							-- Example: 'ExpA, ExpB, ExpC'
**							--      or: 'ExpA%'
**							--      or: 'ExpA, ExpB, ExpC%'
**	  @criteriaSql			-- Optional Filter: Sql "Where clause compatible" text for filtering ResultSet
**							--   Example: Dataset Like 'DatasetA%' And (Charge_State >= 2 Or XCorr >= 6)
**							-- Although this parameter can contain Job, Dataset, and Experiment criteria, it is better to filter for those items using @Jobs, @Datasets, and @Experiments
**	  @returnRowCount		-- Set to True to return a row count; False to return the peptides
**	  @message				-- Status/error message output
**	  @maximumRowCount		-- Maximum number of rows to return; set to 0 or a negative number to return all rows; Default is 0 (no limit)
**	  @minimumPMTQualityScore	-- Set to 0 to include all mass tags, including low quality mass tags
**
**	Auth:	mem
**	Date:	11/28/2007
**
*****************************************************/
(
	@DBName varchar(256) = '',					-- Can be a PT DB or a MT DB
	@AnalysisTool varchar(64) = 'Sequest',		-- Sequest or XTandem
	@Jobs varchar(max) = '',					-- Comma separated list, no wildcards
	@Datasets varchar(max) = '',				-- Comma separated list, % wildcard character allowed
	@Experiments varchar(max) = '',				-- Comma separated list, % wildcard character allowed
	@criteriaSql varchar(max) = '',				-- Sql "Where clause compatible" text for filtering ResultSet
	@returnRowCount varchar(32) = 'False',
	@message varchar(512) = '' output,
	@maximumRowCount int = 0,
	@previewSql tinyint = 0,					-- Preview the Sql used
	@PreviewJobs tinyint = 0,					-- Preview the Jobs that match the filters
	@minimumPMTQualityScore float = 0.0,		-- Only used in MT DBs
	@minimumXCorrCharge1 real = 0,				-- When processing XTandem data, the Normalized_Score (XCorr Equivalent) is tested against this value
	@minimumXCorrCharge2 real = 0,				-- When processing XTandem data, the Normalized_Score (XCorr Equivalent) is tested against this value
	@minimumXCorrCharge3 real = 0,				-- When processing XTandem data, the Normalized_Score (XCorr Equivalent) is tested against this value
	@MinimumDeltaCn2 real = 0
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	declare @result int

	-- DBType 1 is a PMT tag DB (MT_)
	-- DBType 2 is a Peptide DB (PT_)
	-- DBType 3 is a Protein DB (ORF_)
	-- DBType 4 is a UMC DB (UMC_)
	-- DBType 5 is a QC Trends DB (QCT_)
	declare @DBType tinyint	
	
	declare @serverName varchar(64)
	declare @DBPath varchar(256)
	declare @DBID int

	declare @JobCount int
	
	declare @S varchar(max)
	declare @sqlFrom varchar(max)
	declare @sqlWhere varchar(max)
	declare @sqlHaving varchar(max)
	declare @sqlOrderBy varchar(128)

	Declare @AnalysisToolNew varchar(128)
	
	Declare @UsageMessage varchar(512)

	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------
	Set @DBName = IsNull(@DBName, '')
	Set @Jobs = IsNull(@Jobs, '')
	Set @Datasets = IsNull(@Datasets, '')
	Set @Experiments = IsNull(@Experiments, '')
	Set @criteriaSql = IsNull(@criteriaSql, '')
	Set @returnRowCount = IsNull(@returnRowCount, 'false')
	set @message = ''

	Set @maximumRowCount = IsNull(@maximumRowCount, 0)
	Set @DBName = IsNull(@DBName, '')
	Set @previewSql = IsNull(@previewSql, 0)
	Set @PreviewJobs = IsNull(@PreviewJobs, 0)

	Set @minimumPMTQualityScore = IsNull(@minimumPMTQualityScore, 0)
	Set @minimumXCorrCharge1 = IsNull(@minimumXCorrCharge1, 0)
	Set @minimumXCorrCharge2 = IsNull(@minimumXCorrCharge2, 0)
	Set @minimumXCorrCharge3 = IsNull(@minimumXCorrCharge3, 0)
	Set @MinimumDeltaCn2 = IsNull(@MinimumDeltaCn2, 0)
	
	---------------------------------------------------
	-- Validate DB name and determine its location
	---------------------------------------------------
	
	exec @myError = GetDBLocation @DBName, 
						@DBType output, @serverName output, 
						@DBPath output, @DBID output, @message output

	If @myError <> 0
	Begin
		set @message = 'Could not resolve DB name: ' + @DBName
		goto Done
	End

	If @DBID = 0
	Begin
		if Len(IsNull(@message, '')) = 0
			set @message = 'Could not resolve mass tag DB name: ' + @DBName

		set @myerror = 50000
		goto Done
	End
	
	If @DBType <> 1 and @DBType <> 2
	Begin
		set @message = 'Database ' + @DBName + ' is not a PT or MT database; unable to continue'

		set @myerror = 50001
		goto Done
	End
	

	---------------------------------------------------
	-- Determine the DB Schema Version
	---------------------------------------------------
	Declare @DB_Schema_Version real
	Set @DB_Schema_Version = 1

	-- Lookup the DB Schema Version
	-- Note that GetDBSchemaVersionByDBName returns the integer portion of the schema version, and not an error code
	Exec GetDBSchemaVersionByDBName @DBName, @DB_Schema_Version OUTPUT

	If @DB_Schema_Version < 2
	Begin
		set @message = 'The DB Schema Version for ' + @DBName + ' is < 2; unable to continue'
		set @myerror = 50001
		goto Done
	End


	---------------------------------------------------
	-- Make sure @AnalysisTool is valid
	---------------------------------------------------
	
	if @AnalysisTool = 'X!Tandem'
		Set @AnalysisTool = 'XTandem'
		
	if @AnalysisTool <> 'Sequest' and @AnalysisTool <> 'XTandem'
	begin
		set @message = 'Unknown analysis tool: ' + @AnalysisTool + '; valid tools are Sequest and XTandem'
		set @myerror = 50002
		goto Done
	end


	---------------------------------------------------
	-- Cleanup the input parameters
	---------------------------------------------------

	-- Cleanup the True/False parameters
	Exec CleanupTrueFalseParameter @returnRowCount OUTPUT, 1

	-- We need to replace the user-friendly column names in @criteriaSql with the official column names
	-- The results of the replacement will go in @criteriaSqlUpdated
	Declare @criteriaSqlUpdated varchar(max)
	Set @criteriaSqlUpdated = IsNull(@criteriaSql, '')
	If @criteriaSqlUpdated = 'na'
		Set @criteriaSqlUpdated = ''

	If Len(@criteriaSqlUpdated) > 0
	Begin
		-- Note that the udfReplaceMatchingWords function is not case sensitive
		-- Furthermore, it only matches and replaces full words (an underscore is considered a word character)
		Set @criteriaSqlUpdated = dbo.udfReplaceMatchingWords(@criteriaSqlUpdated, 'Job', 'JobTable.Job')
		Set @criteriaSqlUpdated = dbo.udfReplaceMatchingWords(@criteriaSqlUpdated, 'Peptide', 'P.Peptide')
		Set @criteriaSqlUpdated = dbo.udfReplaceMatchingWords(@criteriaSqlUpdated, 'NET_Observed', 'P.GANET_Obs')
		Set @criteriaSqlUpdated = dbo.udfReplaceMatchingWords(@criteriaSqlUpdated, 'Protein', 'Prot.Reference')
		
		If @DBType = 1
		Begin
			-- MT DB
			Set @criteriaSqlUpdated = dbo.udfReplaceMatchingWords(@criteriaSqlUpdated, 'Clean_Sequence', 'MT.Peptide')
			Set @criteriaSqlUpdated = dbo.udfReplaceMatchingWords(@criteriaSqlUpdated, 'Mass_Tag_ID', 'MT.Mass_Tag_ID')
			Set @criteriaSqlUpdated = dbo.udfReplaceMatchingWords(@criteriaSqlUpdated, 'MT_NET_Average', 'MTN.Avg_GANET')
			Set @criteriaSqlUpdated = dbo.udfReplaceMatchingWords(@criteriaSqlUpdated, 'MT_NET_Basis_Count', 'MTN.Cnt_GANET')
		End
		
		If @DBType = 2
		Begin
			-- PT DB
			Set @criteriaSqlUpdated = dbo.udfReplaceMatchingWords(@criteriaSqlUpdated, 'Clean_Sequence', 'MT.Clean_Sequence')
			Set @criteriaSqlUpdated = dbo.udfReplaceMatchingWords(@criteriaSqlUpdated, 'Mass_Tag_ID', 'MT.Seq_ID')
			Set @criteriaSqlUpdated = dbo.udfReplaceMatchingWords(@criteriaSqlUpdated, 'Multiple_Proteins', 'P.Multiple_ORF')
		End
	End
		
	-- Force @maximumRowCount to be negative if @returnRowCount is true
	If @returnRowCount = 'true'
		Set @maximumRowCount = -1


	---------------------------------------------------
	-- Parse @Jobs, @Datasets, and @Experiments to create a proper
	-- SQL where clause containing a mix of 
	-- Where xx In ('A','B') and Where xx Like ('C%') statements
	---------------------------------------------------

	Declare @JobWhereClause varchar(max),
			@DatasetWhereClause varchar(max),
			@ExperimentWhereClause varchar(max)

	Set @JobWhereClause = ''
	Set @DatasetWhereClause = ''
	Set @ExperimentWhereClause = ''

	If Len(@Jobs) > 0
		Set @JobWhereClause = 'TAD.Job IN (' + @Jobs + ')'

	Exec ConvertListToWhereClause @Datasets, 'TAD.Dataset', @entryListWhereClause = @DatasetWhereClause OUTPUT
	Exec ConvertListToWhereClause @Experiments, 'TAD.Experiment', @entryListWhereClause = @ExperimentWhereClause OUTPUT

	Set @sqlWhere = ''			

	If Len(@JobWhereClause) > 0
		Set @sqlWhere = @sqlWhere + ' AND (' + @JobWhereClause + ')'

	If Len(@DatasetWhereClause) > 0
		Set @sqlWhere = @sqlWhere + ' AND (' + @DatasetWhereClause + ')'

	If Len(@experimentWhereClause) > 0
		Set @sqlWhere = @sqlWhere + ' AND (' + @experimentWhereClause + ')'

	---------------------------------------------------
	-- Populate a temporary table with the jobs that match the filter criteria
	---------------------------------------------------

	CREATE TABLE #TmpJobList (
		Job int NOT NULL,
		Dataset varchar(256) NULL,
		Experiment varchar(256) NULL,
		Analysis_Tool varchar(128) NULL
	)	

	Set @S = ''
	Set @S = @S + 'INSERT INTO #TmpJobList (Job, Dataset, Experiment, Analysis_Tool)'
	Set @S = @S + ' SELECT Job, Dataset, Experiment, Analysis_Tool'
	Set @S = @S + ' FROM ' + @DBPath + '.dbo.T_Analysis_Description AS TAD'
	Set @S = @S + ' WHERE Analysis_Tool In (''Sequest'', ''XTandem'')'
	
	If Len(@sqlWhere) > 0
		Set @S = @S + ' ' + @sqlWhere

	If @previewSql <> 0
		Print @S
	
	Exec (@S)
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	Set @JobCount = @myRowCount

	If @JobCount > 0
	Begin -- <a>
		---------------------------------------------------
		-- Filter the jobs in #TmpJobList based on @AnalysisTool
		---------------------------------------------------

		SELECT @JobCount = COUNT(*)
		FROM #TmpJobList
		WHERE Analysis_Tool = @AnalysisTool
		
		If @JobCount > 0
		Begin
			DELETE FROM #TmpJobList
			WHERE Analysis_Tool <> @AnalysisTool
			
		End
		Else
		Begin -- <b>
			-- No jobs match @AnalysisTool
			-- Auto-switch the tool to the most common tool present
			
			Set @AnalysisToolNew = ''
			
			SELECT @AnalysisToolNew = Analysis_Tool
			FROM #TmpJobList
			GROUP BY Analysis_Tool
			ORDER BY Count(*) Desc
			--	
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			If @myError = 0 AND Len(@AnalysisToolNew) > 0
			Begin -- <c>
				Set @Message = 'Warning, auto-switched the Analysis_Tool from ' + @AnalysisTool + ' to ' + @AnalysisToolNew + ' for the requested jobs in ' + @DBName
				
				If Len(@Jobs) > 0
					Set @Message = @Message + '; Job filter: ' + @Jobs

				If Len(@Datasets) > 0
					Set @Message = @Message + '; Dataset filter: ' + @Datasets

				If Len(@Experiments) > 0
					Set @Message = @Message + '; Experiment filter: ' + @Experiments
				
				If @PreviewSql <> 0 OR @PreviewJobs <> 0
					Select @Message As Message
				Else
					Exec PostLogEntry 'Normal', @Message, 'GetMSMSPeptides'
				
				Set @Message = ''
				
				Set @AnalysisTool = @AnalysisToolNew
				
				DELETE FROM #TmpJobList
				WHERE Analysis_Tool <> @AnalysisTool
				--	
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
			End -- </c>
		End -- </b>
	
		SELECT @JobCount = COUNT(*)
		FROM #TmpJobList

	End	-- </a>
	

	If @PreviewJobs <> 0
	Begin
		SELECT *
		FROM #TmpJobList
		ORDER BY Job
		--	
		SELECT @myError = @@error, @myRowCount = @@rowcount

		--
		Set @UsageMessage = Convert(varchar(9), @JobCount) + ' jobs'
		Exec PostUsageLogEntry 'GetMSMSPeptides', @DBName, @UsageMessage
		
		Goto Done
	End
	

	---------------------------------------------------
	-- build the SQL query to get the peptides
	---------------------------------------------------

	-- Construct the base Select clause, optionally limiting the number of rows
	Set @S = ''
	If IsNull(@maximumRowCount,-1) <= 0
		Set @S = @S + 'SELECT'
	Else
		Set @S = @S + 'SELECT TOP ' + Cast(@maximumRowCount As varchar(9))


	Set @S = @S + ' JobTable.Job AS Job,'
	Set @S = @S + ' P.Peptide_ID,'
	Set @S = @S + ' P.Scan_Number,'
	Set @S = @S + ' P.Number_Of_Scans,'
	Set @S = @S + ' P.Charge_State,'
	Set @S = @S + ' P.MH,'
	Set @S = @S + ' P.Peptide AS Peptide,' 
	Set @S = @S + ' P.Scan_Time_Peak_Apex,'
	Set @S = @S + ' P.Peak_Area,'
	Set @S = @S + ' P.GANET_Obs AS NET_Observed,'
	
	If @AnalysisTool = 'Sequest'
	Begin
		Set @S = @S + ' ScoreTable.XCorr,'
		Set @S = @S + ' ScoreTable.DeltaCn,'
		Set @S = @S + ' ScoreTable.DeltaCn2,' 
		Set @S = @S + ' ScoreTable.Sp,' 
		Set @S = @S + ' ScoreTable.RankSp,' 
		Set @S = @S + ' ScoreTable.RankXc,'
		Set @S = @S + ' ScoreTable.DelM,' 
		Set @S = @S + ' ScoreTable.XcRatio,' 
	End

	If @AnalysisTool = 'XTandem'
	Begin
		Set @S = @S + ' ScoreTable.Hyperscore,'
		Set @S = @S + ' 0 AS DeltaCn,'
		Set @S = @S + ' ScoreTable.DeltaCn2,'
		Set @S = @S + ' ScoreTable.Log_EValue,'
		Set @S = @S + ' ScoreTable.Y_Score,'
		Set @S = @S + ' ScoreTable.B_Score,'
		Set @S = @S + ' ScoreTable.DelM,'
	    Set @S = @S + ' ScoreTable.Normalized_Score,'
	End	
	
	Set @S = @S + ' SD.DiscriminantScoreNorm,'
	Set @S = @S + ' SD.Peptide_Prophet_FScore,'
	Set @S = @S + ' SD.Peptide_Prophet_Probability,' 

	If @DBType = 1
		Set @S = @S + ' P.Multiple_Proteins,'
	If @DBType = 2
		Set @S = @S + ' P.Multiple_ORF AS Multiple_Proteins,'
	
	Set @S = @S + ' Prot.Reference AS Protein,' 
	Set @S = @S + ' MTPM.Cleavage_State,' 
	Set @S = @S + ' MTPM.Terminus_State,'
	
	If @DBType = 1
		Set @S = @S + ' MTPM.Missed_Cleavage_Count,'
	If @DBType = 2
		Set @S = @S + ' NULL AS Missed_Cleavage_Count,'
	
	If @DBType = 1	
	Begin
		-- MT DB
		Set @S = @S + ' MT.Peptide AS Clean_Sequence,' 
		Set @S = @S + ' MT.Mass_Tag_ID,'
		Set @S = @S + ' MT.Monoisotopic_Mass,'
		Set @S = @S + ' MT.Mod_Count,' 
		Set @S = @S + ' MT.Mod_Description,'
		Set @S = @S + ' MT.Peptide_Obs_Count_Passing_Filter,'
		Set @S = @S + ' MT.PMT_Quality_Score,'
		Set @S = @S + ' MTN.Avg_GANET AS MT_NET_Average,'
		Set @S = @S + ' MTN.Cnt_GANET AS MT_NET_Basis_Count'
	End

	If @DBType = 2
	Begin
		-- PT DB
		Set @S = @S + ' MT.Clean_Sequence AS Clean_Sequence,' 
		Set @S = @S + ' MT.Seq_ID AS Mass_Tag_ID,'
		Set @S = @S + ' MT.Monoisotopic_Mass,'
		Set @S = @S + ' MT.Mod_Count,' 
		Set @S = @S + ' MT.Mod_Description,'
		Set @S = @S + ' NULL AS Peptide_Obs_Count_Passing_Filter,'
		Set @S = @S + ' NULL AS PMT_Quality_Score,'
		Set @S = @S + ' NULL AS MT_NET_Average,'
		Set @S = @S + ' NULL AS MT_NET_Basis_Count'
	End
	
	-- Construct the From clause
	Set @sqlFrom = ' FROM'
	Set @sqlFrom = @sqlFrom + ' #TmpJobList JobTable INNER JOIN'
	Set @sqlFrom = @sqlFrom + ' DATABASE..T_Peptides P ON JobTable.Job = P.Analysis_ID INNER JOIN'
	
	If @AnalysisTool = 'Sequest'
		Set @sqlFrom = @sqlFrom + ' DATABASE..T_Score_Sequest ScoreTable ON P.Peptide_ID = ScoreTable.Peptide_ID INNER JOIN'
	If @AnalysisTool = 'XTandem'
		Set @sqlFrom = @sqlFrom + ' DATABASE..T_Score_XTandem ScoreTable ON P.Peptide_ID = ScoreTable.Peptide_ID INNER JOIN'
	
	Set @sqlFrom = @sqlFrom + ' DATABASE..T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID INNER JOIN'

	If @DBType = 1
	Begin
		-- MT DB
		Set @sqlFrom = @sqlFrom + ' DATABASE..T_Mass_Tags MT ON P.Mass_Tag_ID = MT.Mass_Tag_ID INNER JOIN'
		Set @sqlFrom = @sqlFrom + ' DATABASE..T_Mass_Tag_to_Protein_Map MTPM ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID INNER JOIN'
		Set @sqlFrom = @sqlFrom + ' DATABASE..T_Proteins Prot ON MTPM.Ref_ID = Prot.Ref_ID INNER JOIN'
		Set @sqlFrom = @sqlFrom + ' DATABASE..T_Mass_Tags_NET MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID'
	End	

	If @DBType = 2
	Begin
		-- PT DB
		Set @sqlFrom = @sqlFrom + ' DATABASE..T_Sequence MT ON P.Seq_ID = MT.Seq_ID INNER JOIN'
		Set @sqlFrom = @sqlFrom + ' DATABASE..T_Peptide_to_Protein_Map MTPM ON P.Peptide_ID = MTPM.Peptide_ID INNER JOIN'
		Set @sqlFrom = @sqlFrom + ' DATABASE..T_Proteins Prot ON MTPM.Ref_ID = Prot.Ref_ID'
	End
	
	
	-- Construct the Where clause
	Set @sqlWhere = ''

	If @DBType = 1 And @minimumPMTQualityScore <> 0
		Set @sqlWhere = @sqlWhere + ' AND (IsNull(MT.PMT_Quality_Score,0) >= ' + Convert(varchar(9), @minimumPMTQualityScore) + ')'

	If @minimumXCorrCharge1 > 0 OR @minimumXCorrCharge2 > 0 OR @minimumXCorrCharge3 > 0
	Begin
		If @AnalysisTool = 'Sequest'
		Begin
			Set @sqlWhere = @sqlWhere + ' AND (P.Charge_State = 1 AND ScoreTable.XCorr >= ' + Convert(varchar(9), @minimumXCorrCharge1) + ' OR'
			Set @sqlWhere = @sqlWhere +      ' P.Charge_State = 2 AND ScoreTable.XCorr >= ' + Convert(varchar(9), @minimumXCorrCharge2) + ' OR'
			Set @sqlWhere = @sqlWhere +      ' P.Charge_State >= 3 AND ScoreTable.XCorr >= ' + Convert(varchar(9), @minimumXCorrCharge3) + ')'
		End

		If @AnalysisTool = 'XTandem'
		Begin
			Set @sqlWhere = @sqlWhere + ' AND (P.Charge_State = 1 AND ScoreTable.Normalized_Score >= ' + Convert(varchar(9), @minimumXCorrCharge1) + ' OR'
			Set @sqlWhere = @sqlWhere +      ' P.Charge_State = 2 AND ScoreTable.Normalized_Score >= ' + Convert(varchar(9), @minimumXCorrCharge2) + ' OR'
			Set @sqlWhere = @sqlWhere +      ' P.Charge_State >= 3 AND ScoreTable.Normalized_Score >= ' + Convert(varchar(9), @minimumXCorrCharge3) + ')'
		End				
	End
	
	If @MinimumDeltaCn2 > 0
		Set @sqlWhere = @sqlWhere + ' AND (ScoreTable.DeltaCn2 >= ' + Convert(varchar(9), @MinimumDeltaCn2) + ')'

	-- Add the Ad Hoc Where criteria, if applicable
	-- However, if the Ad Hoc criteria contains aggregation functions 
	-- like Count or Sum, then it must be added as a Having clause,
	-- which, admittedly, could give unexpected filtering results
	Set @sqlHaving = ''
	If Len(@criteriaSqlUpdated) > 0
	Begin
		If CharIndex('COUNT(', @criteriaSqlUpdated) > 0 OR CharIndex('SUM(', @criteriaSqlUpdated) > 0 OR
		   CharIndex('MAX(', @criteriaSqlUpdated) > 0 OR CharIndex('MIN(', @criteriaSqlUpdated) > 0
			Set @sqlHaving = 'HAVING (' + @criteriaSqlUpdated + ')'
		Else
			Set @sqlWhere = @sqlWhere + ' AND (' + @criteriaSqlUpdated + ')'
	End

	-- Remove the 1st "And" from the start of @sqlWhere
	If Len(@sqlWhere) > 0
		Set @sqlWhere = ' WHERE ' + SubString(@sqlWhere, 5, Len(@sqlWhere))
	
	Set @sqlOrderBy = ' ORDER BY JobTable.Job, P.Scan_Number, P.Peptide_ID'
	
	---------------------------------------------------
	-- Customize the database name and Job table name
	-- for the specific MTDB and match method
	---------------------------------------------------

	set @sqlFrom = replace(@sqlFrom, 'DATABASE..', @DBPath + '.dbo.')

	If @sqlWhere = 'WHERE'
		Set @sqlWhere = ''

	---------------------------------------------------
	-- Obtain the mass tags from the given database
	---------------------------------------------------
		
	Set @S = @S + ' ' + @sqlFrom + ' ' + @sqlWhere + ' ' + @sqlHaving
	
	If @returnRowCount = 'true' And @previewSql = 0
	begin
		-- In order to return the row count, we wrap the Sql text with Count (*) 
		Set @S = 'SELECT Count (*) As ResultSet_Row_Count FROM (' + @S + ') As LookupQ'
		
		Exec (@S)
	end
	Else
	begin
		Set @S = @S + ' ' + @sqlOrderBy
		
		If @previewSql <> 0
			Print @S
		Else
			Exec (@S)
	end
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows; ' + Convert(varchar(9), @JobCount) + ' jobs'
	Exec PostUsageLogEntry 'GetMSMSPeptides', @DBName, @UsageMessage
	
Done:
	If @myError <> 0 And (@previewSql <> 0 Or @PreviewJobs <> 0)
		Select @myError as Error_Code, @Message as Error_Message

	return @myError


GO
GRANT EXECUTE ON [dbo].[GetMSMSPeptides] TO [DMS_SP_User]
GO
