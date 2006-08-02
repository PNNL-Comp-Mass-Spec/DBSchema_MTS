SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ImportNewPeptideAnalyses]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ImportNewPeptideAnalyses]
GO


CREATE PROCEDURE dbo.ImportNewPeptideAnalyses
/****************************************************
**
**	Desc: Imports entries from the analysis job table
**        in the linked DMS database and inserts them
**        into the local analysis description table
**
**		  Also imports the associated datasets,
**		  populating the local datasets table
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**	
**
**		Auth: grk
**		Date: 10/31/2001
**		Mod:  11/05/2003 grk - Modified import criteria to use Result_Type_List
**			  04/14/2004 mem - Added logic to verify that the param file for the job exists in T_Peptide_Mod_Param_File_List
**			  04/15/2004 mem - Implemented use of the T_Import_Organism_DB_File_List to allow filtering of jobs by fasta file
**			  05/04/2004 mem - Added @infoOnly parameter and functionality
**			  07/03/2004 mem - Updated logic to match the new Peptide DB table schema, including populating T_Datasets
**			  08/07/2004 mem - Now updating Process_State and switched to using V_DMS_Peptide_Mod_Param_File_List_Import
**			  08/20/2004 mem - Switched to using T_Process_Config-derived views instead of T_Import_Organism_DB_File_List and T_Import_Analysis_Result_Type_List
**			  08/26/2004 grk - Accounted for V_DMS_Peptide_Mod_Param_File_List_Import moving to MT_Main
**			  09/15/2004 mem - Now populating Separation_sys_type column
**			  10/02/2004 mem - Now populating Enzyme_ID using correct value from DMS
**			  10/07/2004 mem - Switched from using V_DMS_Peptide_Mod_Param_File_List to V_DMS_Param_Files in MT_Main
**			  12/12/2004 mem - Updated to allow import of SIC jobs
**			  03/07/2005 mem - Added support for Campaign, Experiment, and Experiment_Exclusion in T_Process_Config
**			  04/09/2005 mem - Now populating T_Datasets with Instrument and Type from DMS
**			  05/05/2005 mem - Added use of RequireExistingDatasetForNewSICJobs from T_Process_Step_Control, which dictates whether or not new SIC jobs are required to have a dataset name matching an existing or newly imported dataset name
**			  07/18/2005 mem - Now populating T_Analysis_Description with Instrument, Internal_Standard, and Labelling (Instrument was previously in T_Datasets)
**			  11/13/2005 mem - Now populating Acq_Time_Start, Acq_Time_End, and Scan_Count in T_Datasets
**			  11/30/2005 mem - Added parameter @PreviewSql
**    
*****************************************************/
	@NextProcessState int = 10,
	@entriesAdded int = 0 output,
	@infoOnly tinyint = 0,
	@PreviewSql tinyint = 0				-- Set to 1 to display the table population Sql statements
As
	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @DatasetsAdded int
	declare @MissingParamFileCount int
	declare @MatchCount int
	declare @FilterOnOrgDB tinyint
	declare @FilterOnCampaign tinyint

	declare @AllowSIC tinyint
	declare @RequireExistingDatasetForNewSICJobs tinyint
	
	declare @MaxLoopCount int
	declare @LoopCount int

	declare @expListCount int
	declare @expListCountExcluded int

	Declare @ResultTypeFilter varchar(128)
	Declare @OrganismDBNameFilter varchar(128)
	Declare @SICDSFilter varchar(128)
	
	declare @filterValueLookupTableName varchar(256)
	declare @filterLookupAdditionalWhereClause varchar(2000)
	declare @filterMatchCount int
	
	set @DatasetsAdded = 0
	
	declare @message varchar(255)
	
	declare @organism varchar(64)
	set @organism = ''
	
	Declare @sql varchar(2048)
	Declare @CrLf char(2)
	
	Set @CrLf = char(10) + char(13)
	
	---------------------------------------------------
	-- get organism name for this peptide database
	---------------------------------------------------
	--
	SELECT @organism = PDB_Organism
	FROM MT_Main.dbo.T_Peptide_Database_List
	WHERE (PDB_Name = DB_Name())
	--	
	if @organism = ''
	begin
		set @message = 'Could not get organism name from MT_Main'
		execute PostLogEntry 'Error', @message, 'ImportNewPeptideAnalyses'
		return 33
	end

	---------------------------------------------------
	-- Define the additional where clause for the call to ParseFilterList
	---------------------------------------------------

	set @filterLookupAdditionalWhereClause = 'Organism = ''' + @organism + ''''

	CREATE TABLE #TmpFilterList (
		Value varchar(128)
	)			

	CREATE TABLE #TmpExperiments (
		Experiment varchar(128)
	)
	
	CREATE TABLE #TmpExperimentsExcluded (
		Experiment varchar(128)
	)

	set @filterValueLookupTableName = 'MT_Main.dbo.V_DMS_Analysis_Job_Import_Ex'


	---------------------------------------------------
	-- Count number of Organism_DB_File_Name entries in T_Process_Config
	---------------------------------------------------
	--
	Set @MatchCount = 0
	SELECT @MatchCount = COUNT(*)
	FROM V_Import_Organism_DB_File_List
	WHERE Len(Value) > 0	
	--
	select @myError = @@error, @myRowCount = @@rowcount			
	--
	If @MatchCount > 0
		Set	@FilterOnOrgDB = 1
	Else
		Set @FilterOnOrgDB = 0

	---------------------------------------------------
	-- See if SIC jobs are listed as a valid result type
	---------------------------------------------------
	--
	Set @MatchCount = 0
	SELECT @MatchCount = COUNT(*)
	FROM V_Import_Analysis_Result_Type_List
	WHERE Value = 'SIC'
	--
	select @myError = @@error, @myRowCount = @@rowcount			
	--
	If @MatchCount > 0
		Set	@AllowSIC = 1
	Else
		Set @AllowSIC = 0

	---------------------------------------------------
	-- See if RequireExistingDatasetForNewSICJobs is defined; assume True
	---------------------------------------------------
	--
	Set @RequireExistingDatasetForNewSICJobs = 1
	SELECT @RequireExistingDatasetForNewSICJobs = IsNull(enabled, 1)
	FROM T_Process_Step_Control
	WHERE Processing_Step_Name = 'RequireExistingDatasetForNewSICJobs'
	--
	select @myError = @@error, @myRowCount = @@rowcount			
	
	
	---------------------------------------------------
	-- Count number of Campaign entries in T_Process_Config
	---------------------------------------------------
	--
	Set @MatchCount = 0
	SELECT @MatchCount = COUNT(*)
	FROM T_Process_Config
	WHERE [Name] = 'Campaign'
	--
	If @MatchCount > 0
		Set	@FilterOnCampaign = 1
	Else
		Set @FilterOnCampaign = 0


	---------------------------------------------------
	-- See if any experiments are defined in T_Process_Config
	-- Populate #TmpExperiments with list of experiment names
	-- If any contain a percent sign, then use that as a matching
	--  parameter to populate #TmpExperiments
	---------------------------------------------------
	--
	set @expListCount = 0
	set @filterMatchCount = 0
	Exec @myError = ParseFilterList 'Experiment', @filterValueLookupTableName, 'Experiment', @filterLookupAdditionalWhereClause, @filterMatchCount OUTPUT
	--
	if @myError <> 0
	begin
		set @message = 'Error looking up experiment inclusion filter names'
		set @myError = 40006
		goto Done
	end
	Else
	begin
		INSERT INTO #TmpExperiments (Experiment)
		SELECT Value FROM #TmpFilterList
		--
		select @myError = @@error, @expListCount = @@rowcount
		
		If @expListCount = 0 And @filterMatchCount > 0
		Begin
			-- The user defined an experiment inclusion filter, but none matched
			-- Add a bogus entry to #TmpExperiments to guarantee that no jobs will match
			INSERT INTO #TmpExperiments (Experiment)
			VALUES ('FakeExperiment_' + Convert(varchar(64), NewId()))
			--
			select @myError = @@error, @myRowCount = @@rowcount			
		End
	End


	---------------------------------------------------
	-- See if any excluded experiments are defined in T_Process_Config
	-- Populate #TmpExperimentsExcluded with list of experiment names
	---------------------------------------------------
	--
	set @expListCountExcluded = 0
	Exec @myError = ParseFilterList 'Experiment_Exclusion', @filterValueLookupTableName, 'Experiment', @filterLookupAdditionalWhereClause
	--
	if @myError <> 0
	begin
		set @message = 'Error looking up experiment exclusion filter names'
		set @myError = 40007
		goto Done
	end
	Else
	begin
		INSERT INTO #TmpExperimentsExcluded (Experiment)
		SELECT Value FROM #TmpFilterList
		--
		select @myError = @@error, @expListCountExcluded = @@rowcount
	End


	---------------------------------------------------
	-- Import new analysis jobs
	---------------------------------------------------
	--
	-- Get entries from the analysis job table 
	-- in the linked DMS database that are associated
	-- with the given organism, that match the ResultTypes in
	-- T_Process_Config,
	-- and that have not already been imported

	-- Create a temporary table to hold the new jobs and Dataset IDs

	if exists (select * from dbo.sysobjects where id = object_id(N'[#NewAnalysisJobs]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table [#NewAnalysisJobs]

	CREATE TABLE #NewAnalysisJobs (
		[Job] [int] NOT NULL ,
		[Dataset] [varchar] (128) NOT NULL ,
		[Dataset_ID] [int] NOT NULL ,
		[Experiment] [varchar] (64) NULL ,
		[Campaign] [varchar] (64) NULL ,
		[Organism] [varchar] (50) NOT NULL ,
		[Instrument_Class] [varchar] (32) NOT NULL ,
		[Instrument] [varchar] (64) NULL ,
		[Analysis_Tool] [varchar] (64) NOT NULL ,
		[Parameter_File_Name] [varchar] (255) NOT NULL ,
		[Settings_File_Name] [varchar] (255) NULL ,
		[Organism_DB_Name] [varchar] (64) NOT NULL ,
		[Vol_Client] [varchar] (128) NOT NULL ,
		[Vol_Server] [varchar] (128) NULL ,
		[Storage_Path] [varchar] (255) NOT NULL ,
		[Dataset_Folder] [varchar] (128) NOT NULL ,
		[Results_Folder] [varchar] (128) NOT NULL ,
		[Completed] [datetime] NULL ,
		[ResultType] [varchar] (32) NULL ,
		[Enzyme_ID] [int] NULL ,
		[Labelling] [varchar] (64) NULL ,
		[Separation_Sys_Type] [varchar] (50) NULL ,
		[Internal_Standard] [varchar] (50) NULL
	) ON [PRIMARY]


	-- Since SIC jobs can be required to only be imported if a Non-SIC job exists with the same dataset,
	-- we need to poll DMS twice, once for the Non-SIC jobs, and once for the SIC jobs
	If @AllowSIC = 1
		Set @MaxLoopCount = 2
	Else
		Set @MaxLoopCount = 1

	
	Set @LoopCount = 0
	While @LoopCount < @MaxLoopCount
	Begin
	
		If @LoopCount = 0
		Begin
			-- Import Non-SIC Jobs
			Set @ResultTypeFilter = ' AND ResultType IN (SELECT Value FROM V_Import_Analysis_Result_Type_List) AND (ResultType <> ''SIC'')'
			Set @OrganismDBNameFilter = ' AND (OrganismDBName IN (SELECT Value FROM V_Import_Organism_DB_File_List)) '
			Set @SICDSFilter = ''
		End
		Else
		Begin
			-- Import SIC Jobs, optionally requiring that a dataset exist in #NewAnalysisJobs or T_Analysis_Description
			Set @ResultTypeFilter = ' AND (ResultType = ''SIC'')'
			Set @OrganismDBNameFilter = ' '
			
			If @RequireExistingDatasetForNewSICJobs = 0
				Set @SICDSFilter = ''
			Else
			Begin
				Set @SICDSFilter = ''
				Set @SICDSFilter = @SICDSFilter + ' AND Dataset IN (SELECT DISTINCT Dataset FROM T_Analysis_Description'
				Set @SICDSFilter = @SICDSFilter + ' UNION SELECT DISTINCT Dataset FROM #NewAnalysisJobs)'
			End

		End


		-- Populate the temporary table with new jobs from DMS
		--
		Set @sql = ''
		Set @sql = @sql + ' INSERT INTO #NewAnalysisJobs'
		Set @sql = @sql + '  (Job, Dataset, Dataset_ID, Experiment, Campaign, Organism,'
		Set @sql = @sql + '  Instrument_Class, Instrument, Analysis_Tool, Parameter_File_Name,'
		Set @sql = @sql + '  Organism_DB_Name, Vol_Client, Vol_Server, Storage_Path,'
		Set @sql = @sql + '  Dataset_Folder, Results_Folder, Settings_File_Name, Completed,'
		Set @sql = @sql + '  ResultType, Enzyme_ID, Labelling, Separation_Sys_Type, Internal_Standard) ' + Char(13)
  		Set @sql = @sql + ' SELECT'
		Set @sql = @sql + '  Job, Dataset, DatasetID, Experiment, Campaign, Organism,  '
		Set @sql = @sql + '  InstrumentClass, InstrumentName, AnalysisTool, ParameterFileName,' 
		Set @sql = @sql + '  OrganismDBName, VolClient, VolServer, StoragePath,'
		Set @sql = @sql + '  DatasetFolder, ResultsFolder, SettingsFileName, Completed,'
		Set @sql = @sql + '  ResultType, EnzymeID, Labelling, SeparationSysType, [Internal Standard]'
		Set @sql = @sql + ' FROM MT_Main.dbo.V_DMS_Analysis_Job_Import_Ex'
		Set @sql = @sql + ' WHERE Job NOT IN (SELECT Job FROM T_Analysis_Description)'
		Set @sql = @sql + @ResultTypeFilter
		Set @sql = @sql + '    AND Organism = ''' + @organism + ''''

		If @FilterOnOrgDB = 1
			Set @sql = @sql + @OrganismDBNameFilter

		Set @sql = @sql + @SICDSFilter
		
		if @FilterOnCampaign = 1
			Set @sql = @sql + 'AND Campaign IN (SELECT Value FROM T_Process_Config WHERE [Name] = ''Campaign'') '

		if @expListCount > 0
		begin
			set @sql = @sql + 'AND Experiment IN '
			set @sql = @sql + '( '
			set @sql = @sql + '	SELECT Experiment FROM #TmpExperiments '
			set @sql = @sql + ') '
		end
		
		if @expListCountExcluded > 0
		begin
			set @sql = @sql + 'AND NOT Experiment IN '
			set @sql = @sql + '( '
			set @sql = @sql + '	SELECT Experiment FROM #TmpExperimentsExcluded '
			set @sql = @sql + ') '
		End
		

		Set @sql = @sql + ' ORDER BY Job'
		
		If @PreviewSql <> 0
		Begin
			if @LoopCount = 0
				Print '-- Sql to import non-MASIC jobs'
			else
				Print '-- Sql to import MASIC jobs'
			Print @Sql + @CrLf
		End
			
		Exec (@sql)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
			
	
		Set @LoopCount = @LoopCount + 1
	End
		
	---------------------------------------------------
	-- Examine the temporary table to find new datasets
	-- Need to add the datasets to T_Datasets before populating T_Analysis_Description
	---------------------------------------------------

	If @infoOnly = 0
	begin
		-- Add any new datasets to T_Datasets
		-- We'll lookup Type, Created_DMS, and the additional info below
		INSERT INTO T_Datasets (Dataset_ID, Dataset, Created, Dataset_Process_State)
		SELECT TAD.Dataset_ID, TAD.Dataset, GetDate() AS Created, @NextProcessState AS Process_State
		FROM #NewAnalysisJobs AS TAD
			LEFT OUTER JOIN T_Datasets ON TAD.Dataset_ID = T_Datasets.Dataset_ID
		WHERE T_Datasets.Dataset_ID IS NULL
		GROUP BY TAD.Dataset_ID, TAD.Dataset
		--
		SELECT @DatasetsAdded = @@rowcount, @myError = @@error
		
		If @myError <> 0
		Begin
			Set @message = 'Error adding new datasets to T_Datasets: ' + convert(varchar(9), @myError)
			If @infoOnly = 0 
				execute PostLogEntry 'Error', @message, 'ImportNewPeptideAnalyses'
		End
		
		If @DatasetsAdded > 0
		Begin
			-- Lookup the additional stats for the new datasets
			UPDATE T_Datasets
			SET Type = DDI.Type,
				Created_DMS = DDI.Created,
				Acq_Time_Start = DDI.[Acquisition Start],
				Acq_Time_End = DDI.[Acquisition End],
				Scan_Count = DDI.[Scan Count]
			FROM  MT_Main.dbo.V_DMS_Dataset_Import_Ex AS DDI INNER JOIN T_Datasets ON T_Datasets.Dataset_ID = DDI.ID
			WHERE T_Datasets.Created_DMS Is Null
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			If @myError <> 0
			Begin
				Set @message = 'Error updating DMS Creation time for new datasets: ' + convert(varchar(9), @myError)
				If @infoOnly = 0 
					execute PostLogEntry 'Error', @message, 'ImportNewPeptideAnalyses'
			End
		End
	End

	
	---------------------------------------------------
	-- Now populate T_Analysis_Description with the jobs in #NewAnalysisJobs
	---------------------------------------------------
	
	Set @sql = ''

	if @infoOnly = 0
	begin	
		Set @sql = @sql + ' INSERT INTO T_Analysis_Description'
		Set @sql = @sql + ' (Job, Dataset, Dataset_ID, Experiment, Campaign, Organism,'
		Set @sql = @sql + ' Instrument_Class, Instrument, Analysis_Tool, Parameter_File_Name,'
		Set @sql = @sql + ' Organism_DB_Name, Vol_Client, Vol_Server, Storage_Path,'
		Set @sql = @sql + ' Dataset_Folder, Results_Folder, Settings_File_Name,'
		Set @sql = @sql + ' Completed, ResultType, Enzyme_ID, Labelling, Separation_Sys_Type,'
		Set @sql = @sql + ' Internal_Standard, Created, Process_State)' + Char(13)
	end
  	Set @sql = @sql + ' SELECT'
	Set @sql = @sql + '  Job, AJ.Dataset, AJ.Dataset_ID, Experiment, Campaign, Organism, '
	Set @sql = @sql + '  Instrument_Class, AJ.Instrument, Analysis_Tool, Parameter_File_Name, ' 
	Set @sql = @sql + '  Organism_DB_Name, Vol_Client, Vol_Server, Storage_Path,'
	Set @sql = @sql + '  Dataset_Folder, Results_Folder, Settings_File_Name,'
	Set @sql = @sql + '  Completed, ResultType, Enzyme_ID, Labelling, Separation_Sys_Type,'
	Set @sql = @sql + '  Internal_Standard, GetDate() AS Created,'
	Set @sql = @sql + '  CASE WHEN ResultType IN (''Peptide_Hit'', ''SIC'')'
    Set @sql = @sql + '  THEN ' + Convert(varchar(12), @NextProcessState)
    Set @sql = @sql + '  ELSE 0'
    Set @sql = @sql + '  END AS ''Process_State'''
	Set @sql = @sql + ' FROM  #NewAnalysisJobs as AJ'
	if @infoOnly = 0
	begin
		Set @sql = @sql + ' INNER JOIN T_Datasets ON AJ.Dataset_ID = T_Datasets.Dataset_ID'
	end
	Set @sql = @sql + ' WHERE AJ.Job NOT IN '
	Set @sql = @sql + ' (SELECT Job FROM T_Analysis_Description)'
	Set @sql = @sql + ' ORDER BY Job'

	If @PreviewSql <> 0
	Begin
		print '-- Sql to copy data from #NewAnalysisJobs to T_Analysis_Description'
		Print @Sql + @CrLf
	End
	Exec (@sql)
	--
	SELECT @entriesAdded = @@rowcount, @myError = @@error


	
	Set @MissingParamFileCount = 0
	if @infoOnly = 0
	begin	
		-- Verify that the inserted Jobs have param files that are defined in MT_Main..V_DMS_Peptide_Mod_Param_File_List_Import
		--
		-- Make sure MT_Main..V_DMS_Peptide_Mod_Param_File_List_Import actually has been populated; if it hasn't, 
		--  then all of the newly imported jobs need to be set at state 4
		
		Set @MatchCount = 0
		SELECT @MatchCount = COUNT(*)
		FROM MT_Main..V_DMS_Param_Files
		
		If @MatchCount = 0
			-- No param files are present; set the states for all new jobs to state 4
			UPDATE	T_Analysis_Description
			SET		Process_State = 4, Last_Affected = GetDate()
			WHERE	Process_State = @NextProcessState
		Else
			-- Param files are present; set the states for jobs with unknown param files to state 4
			UPDATE	T_Analysis_Description
			SET		Process_State = 4, Last_Affected = GetDate()
			WHERE	Process_State = @NextProcessState AND
					ResultType = 'Peptide_Hit' AND
					Parameter_File_Name NOT IN (SELECT DISTINCT Param_File_Name FROM MT_Main..V_DMS_Param_Files)
		--
		Set @MissingParamFileCount = @@RowCount
	end
	
		
	-- Post the log entry messages
	--
	set @message = 'Import New Analysis Jobs: ' + convert(varchar(11), @entriesAdded) + ' jobs added'
	If @infoOnly = 0 And (@entriesAdded > 0 Or @DatasetsAdded > 0)
		execute PostLogEntry 'Normal', @message, 'ImportNewPeptideAnalyses'

	set @message = 'Import Datasets for New Analyses: ' + convert(varchar(11), @DatasetsAdded) + ' datasets added'
	If @infoOnly = 0 And (@entriesAdded > 0 Or @DatasetsAdded > 0)
		execute PostLogEntry 'Normal', @message, 'ImportNewPeptideAnalyses'
	
	If @MissingParamFileCount > 0
	Begin
		Set @message = 'Analyses were added with unknown param files: ' + convert(varchar(19), @MissingParamFileCount) + '; Process_State set to 4'
		If @infoOnly = 0 
			execute PostLogEntry 'Error', @message, 'ImportNewPeptideAnalyses'
	End

Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

