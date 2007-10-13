/****** Object:  StoredProcedure [dbo].[ImportNewPeptideAnalyses] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ImportNewPeptideAnalyses
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
**	Auth:	grk
**	Date:	10/31/2001
**			11/05/2003 grk - Modified import criteria to use Result_Type_List
**			04/14/2004 mem - Added logic to verify that the param file for the job exists in T_Peptide_Mod_Param_File_List
**			04/15/2004 mem - Implemented use of the T_Import_Organism_DB_File_List to allow filtering of jobs by fasta file
**			05/04/2004 mem - Added @infoOnly parameter and functionality
**			07/03/2004 mem - Updated logic to match the new Peptide DB table schema, including populating T_Datasets
**			08/07/2004 mem - Now updating Process_State and switched to using V_DMS_Peptide_Mod_Param_File_List_Import
**			08/20/2004 mem - Switched to using T_Process_Config-derived views instead of T_Import_Organism_DB_File_List and T_Import_Analysis_Result_Type_List
**			08/26/2004 grk - Accounted for V_DMS_Peptide_Mod_Param_File_List_Import moving to MT_Main
**			09/15/2004 mem - Now populating Separation_sys_type column
**			10/02/2004 mem - Now populating Enzyme_ID using correct value from DMS
**			10/07/2004 mem - Switched from using V_DMS_Peptide_Mod_Param_File_List to V_DMS_Param_Files in MT_Main
**			12/12/2004 mem - Updated to allow import of SIC jobs
**			03/07/2005 mem - Added support for Campaign, Experiment, and Experiment_Exclusion in T_Process_Config
**			04/09/2005 mem - Now populating T_Datasets with Instrument and Type from DMS
**			05/05/2005 mem - Added use of RequireExistingDatasetForNewSICJobs from T_Process_Step_Control, which dictates whether or not new SIC jobs are required to have a dataset name matching an existing or newly imported dataset name
**			07/18/2005 mem - Now populating T_Analysis_Description with Instrument, Internal_Standard, and Labelling (Instrument was previously in T_Datasets)
**			11/13/2005 mem - Now populating Acq_Time_Start, Acq_Time_End, and Scan_Count in T_Datasets
**			11/30/2005 mem - Added parameter @PreviewSql
**			12/11/2005 mem - Added support for XTandem results
**			12/15/2005 mem - Now populating T_Analysis_Description with PreDigest_Internal_Std, PostDigest_Internal_Std, and Dataset_Internal_Std (previously named Internal_Standard)
**			02/07/2006 mem - Added parameter @JobListOverride
**			02/24/2006 mem - Updated to only consider the jobs in @JobListOverride if defined; previously, would still add jobs passing the default filters even if @JobListOverride contained one or more jobs
**			02/27/2006 mem - Added support for Dataset_DMS_Creation_Date_Minimum in T_Process_Config
**			03/07/2006 mem - Added support for Enzyme_ID in T_Process_Config
**			06/04/2006 mem - Now populating T_Analysis_Description with Protein_Collection_List and Protein_Options_List
**			06/10/2006 mem - Added support for Protein_Collection_Filter, Seq_Direction_Filter, and Protein_Collection_and_Protein_Options_Combo in T_Process_Config
**			06/13/2006 mem - Updated to recognize Protein_Collection_List jobs by only testing the ProteinCollectionList field in V_Import_Analysis_Result_Type_List for 'na' or '' rather than also testing the OrganismDBName field
**			07/18/2006 mem - Added support for Campaign_Exclusion in T_Process_Config
**			07/31/2006 mem - Increased size of @JobListOverride and switched to use udfParseDelimitedList to parse the list
**			11/29/2006 mem - Now adding a line feed character in key places to aid readability when using @PreviewSql = 1
**			12/02/2006 mem - Now using udfParseDelimitedIntegerList to parse @JobListOverride
**			03/14/2007 mem - Changed @JobListOverride parameter from varchar(8000) to varchar(max)
**			03/18/2007 mem - Now obtaining StoragePathClient and StoragePathServer from V_DMS_Analysis_Job_Import_Ex
**			05/10/2007 mem - Added parameter @UseCachedDMSDataTables and parameter @message (Ticket:422)
**						   - Switched to Try/Catch error handling
**			10/07/2007 mem - Increased size of Protein_Collection_List to varchar(max)
**    
*****************************************************/
(
	@NextProcessState int = 10,
	@entriesAdded int = 0 output,
	@message varchar(512) = '' output,
	@infoOnly tinyint = 0,
	@JobListOverride varchar(max) = '',
	@PreviewSql tinyint = 0,					-- Set to 1 to display the table population Sql statements; if this is 1, then forces @infoOnly to be 1
	@UseCachedDMSDataTables tinyint = 1			-- Set to 1 to use tables T_DMS_Analysis_Job_Info_Cached and T_DMS_Dataset_Info_Cached in MT_Main rather than the views that connect to DMS; if any jobs listed in @JobListOverride are not found in T_DMS_Analysis_Job_Info_Cached, then @UseCachedDMSDataTables will automatically be set to 0
)
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
	declare @FilterOnEnzymeID tinyint

	declare @AllowSIC tinyint
	declare @RequireExistingDatasetForNewSICJobs tinyint
	
	declare @MaxLoopCount int
	declare @LoopCount int

	declare @campaignListCountExcluded int
	declare @expListCount int
	declare @expListCountExcluded int

	Declare @ResultTypeFilter varchar(128)
	Declare @OrganismDBNameFilter varchar(512)
	Declare @SICDSFilter varchar(128)

	Declare @S varchar(8000)
	declare @JobInfoTable varchar(256)
	declare @DatasetInfoTable varchar(256)
	
	declare @filterValueLookupTableName varchar(256)
	set @filterValueLookupTableName = ''

	declare @filterLookupAdditionalWhereClause varchar(2000)
	declare @filterMatchCount int

	declare @UsingJobListOverride tinyint
	set @UsingJobListOverride =0

	set @DatasetsAdded = 0
	
	declare @organism varchar(64)
	set @organism = ''
	
	Declare @Lf char(1)
	Set @Lf = char(10)

	Declare @CrLf char(2)
	Set @CrLf = char(10) + char(13)

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		---------------------------------------------------
		-- Validate the inputs
		---------------------------------------------------
		--
		Set @CurrentLocation = 'Validate the inputs'

		Set @entriesAdded = 0
		Set @message = ''
		Set @JobListOverride = LTrim(RTrim(IsNull(@JobListOverride, '')))

		Set @infoOnly = IsNull(@infoOnly, 0)
		If @infoOnly <> 0
			Set @infoOnly = 1
			
		Set @PreviewSql = IsNull(@PreviewSql, 0)
		If @PreviewSql <> 0
			Set @infoOnly = 1

		Set @UseCachedDMSDataTables = IsNull(@UseCachedDMSDataTables, 0)
		If @UseCachedDMSDataTables <> 0
			Set @UseCachedDMSDataTables = 1

		---------------------------------------------------
		-- get organism name for this peptide database
		---------------------------------------------------
		--
		Set @CurrentLocation = 'Get Organism Name'

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
		--
		Set @CurrentLocation = 'Create temporary tables'

		set @filterLookupAdditionalWhereClause = 'Organism = ''' + @organism + ''''

		CREATE TABLE #TmpFilterList (
			Value varchar(128)
		)			

		CREATE TABLE #TmpCampaignsExcluded (
			Campaign varchar(128)
		)
		
		CREATE TABLE #TmpExperiments (
			Experiment varchar(128)
		)
		
		CREATE TABLE #TmpExperimentsExcluded (
			Experiment varchar(128)
		)

		If @PreviewSql <> 0
			CREATE TABLE #PreviewSqlData (
				Filter_Type varchar(128), 
				Value varchar(128) NULL
			)

		If Len(@JobListOverride) > 0
		Begin
			---------------------------------------------------
			-- Populate a temporary table with the jobs in @JobListOverride
			---------------------------------------------------
			--
			CREATE TABLE #T_Tmp_JobListOverride (
				JobOverride int
			)
			
			INSERT INTO #T_Tmp_JobListOverride (JobOverride)
			SELECT Value
			FROM dbo.udfParseDelimitedIntegerList(@JobListOverride, ',')
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0
			begin
				set @message = 'Error parsing Job Override list'
				goto Done
			end

			Set @UsingJobListOverride = 1
			
			If @InfoOnly <> 0
				SELECT JobOverride
				FROM #T_Tmp_JobListOverride
				ORDER BY JobOverride
				
			If @UseCachedDMSDataTables = 1
			Begin
				-- Make sure all of the jobs defined in #T_Tmp_JobListOverride are present in T_DMS_Analysis_Job_Info_Cached
				-- If not, then we'll change @UseCachedDMSDataTables to 0
				Set @MatchCount = 0
				SELECT @MatchCount = COUNT(*)
				FROM #T_Tmp_JobListOverride JL LEFT OUTER JOIN 
					 MT_Main.dbo.T_DMS_Analysis_Job_Info_Cached DAJI ON JL.JobOverride = DAJI.Job
				WHERE DAJI.Job Is Null
				
				If @MatchCount > 0
				Begin
					Set @UseCachedDMSDataTables = 0
					
					If @InfoOnly <> 0
					Begin
						Set @message = 'Warning: Found ' + Convert(varchar(19), @MatchCount)
						If @MatchCount = 1
							Set @message = @message + ' job in @JobListOverride that was not'
						Else
							Set @message = @message + ' jobs in @JobListOverride that were not'
						
						Set @message = @message + ' in MT_Main.dbo.T_DMS_Analysis_Job_Info_Cached; @UseCachedDMSDataTables has been set to 0'
						
						SELECT @message AS WarningMessage
						Set @message = ''
					End
				End
			End
		End

		---------------------------------------------------
		-- Define the job and dataset info table names
		---------------------------------------------------
		If @UseCachedDMSDataTables = 0
		Begin
			Set @JobInfoTable = 'MT_Main.dbo.V_DMS_Analysis_Job_Import_Ex'
			Set @DatasetInfoTable= 'MT_Main.dbo.V_DMS_Dataset_Import_Ex'
		End
		Else
		Begin
			Set @JobInfoTable = 'MT_Main.dbo.T_DMS_Analysis_Job_Info_Cached'
			Set @DatasetInfoTable= 'MT_Main.dbo.T_DMS_Dataset_Info_Cached'
		End
		
		-- Define the table where we will look up jobs from when calling ParseFilterList
		set @filterValueLookupTableName = @JobInfoTable

		Set @CurrentLocation = 'Determine import options'

		---------------------------------------------------
		-- See if Dataset_DMS_Creation_Date_Minimum is defined in T_Process_Config
		---------------------------------------------------
		--
		declare @DatasetDMSCreationDateMinimum datetime
		declare @DateText varchar(64)
		
		Set @DateText = ''
		SELECT @DateText = Value
		FROM T_Process_Config
		WHERE [Name] = 'Dataset_DMS_Creation_Date_Minimum' AND Len(Value) > 0
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Error looking up Dataset_DMS_Creation_Date_Minimum parameter'
			set @myError = 40005
			goto Done
		end
		--
		if @myRowCount = 0 OR IsDate(@DateText) = 0
			Set @DateText = ''


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
		-- See if any excluded campaigns are defined in T_Process_Config
		-- Populate #TmpCampaignsExcluded with list of campaign names
		---------------------------------------------------
		--
		set @campaignListCountExcluded = 0
		Exec @myError = ParseFilterList 'Campaign_Exclusion', @filterValueLookupTableName, 'Campaign', @filterLookupAdditionalWhereClause
		--

		if @myError <> 0
		begin
			set @message = 'Error looking up campaign exclusion filter names'
			set @myError = 40007
			goto Done
		end
		Else
		begin
			INSERT INTO #TmpCampaignsExcluded (Campaign)
			SELECT Value FROM #TmpFilterList
			--
			select @myError = @@error, @myRowCount= @@rowcount
			
			Set @campaignListCountExcluded = @myRowCount

			If @PreviewSql <> 0
				INSERT INTO #PreviewSqlData (Filter_Type, Value)
				SELECT 'Campaign Exclusion', Campaign 
				FROM #TmpCampaignsExcluded
		End


		---------------------------------------------------
		-- Count number of Enzyme_ID entries in T_Process_Config
		---------------------------------------------------
		--
		Set @MatchCount = 0
		SELECT @MatchCount = COUNT(*)
		FROM T_Process_Config
		WHERE [Name] = 'Enzyme_ID'
		--
		If @MatchCount > 0
			Set	@FilterOnEnzymeID = 1
		Else
			Set @FilterOnEnzymeID = 0


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
			select @myError = @@error, @myRowCount = @@rowcount
			
			Set @expListCount = @myRowCount
			
			If @expListCount = 0 And @filterMatchCount > 0
			Begin
				-- The user defined an experiment inclusion filter, but none matched
				-- Add a bogus entry to #TmpExperiments to guarantee that no jobs will match
				INSERT INTO #TmpExperiments (Experiment)
				VALUES ('FakeExperiment_' + Convert(varchar(64), NewId()))
				--
				select @myError = @@error, @myRowCount = @@rowcount			
			End

			If @PreviewSql <> 0
				INSERT INTO #PreviewSqlData (Filter_Type, Value)
				SELECT 'Experiment Inclusion', Experiment 
				FROM #TmpExperiments

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
			select @myError = @@error, @myRowCount = @@rowcount
			
			Set @expListCountExcluded = @myRowCount

			If @PreviewSql <> 0
				INSERT INTO #PreviewSqlData (Filter_Type, Value)
				SELECT 'Experiment Exclusion', Experiment 
				FROM #TmpExperimentsExcluded
		End

		-----------------------------------------------
		-- Populate a temporary table with the list of known Result Types
		-----------------------------------------------
		CREATE TABLE #T_ResultTypeList (
			ResultType varchar(64)
		)
		
		INSERT INTO #T_ResultTypeList (ResultType) Values ('Peptide_Hit')
		INSERT INTO #T_ResultTypeList (ResultType) Values ('XT_Peptide_Hit')
		INSERT INTO #T_ResultTypeList (ResultType) Values ('SIC')


		---------------------------------------------------
		-- Import new analysis jobs
		---------------------------------------------------
		--
		-- Get entries from the analysis job table 
		-- in the linked DMS database that are associated
		-- with the given organism, that match the ResultTypes in
		-- T_Process_Config, and that have not already been imported

		-- Create a temporary table to hold the new jobs and Dataset IDs

		if exists (select * from dbo.sysobjects where id = object_id(N'[#TmpNewAnalysisJobs]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [#TmpNewAnalysisJobs]

		CREATE TABLE #TmpNewAnalysisJobs (
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
			[Protein_Collection_List] [varchar] (max) NOT NULL,
			[Protein_Options_List] [varchar] (256) NOT NULL,
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
			[PreDigest_Internal_Std] [varchar] (50) NULL,
			[PostDigest_Internal_Std] [varchar] (50) NULL,
			[Dataset_Internal_Std] [varchar] (50) NULL,
			[Process_State] int NOT NULL,
			[Valid] tinyint NOT NULL DEFAULT (0)
		) ON [PRIMARY]

		-- Add an index to #TmpNewAnalysisJobs on column Job
		CREATE CLUSTERED INDEX #IX_NewAnalysisJobs_Job ON #TmpNewAnalysisJobs(Job)

		-- Add an index to #TmpNewAnalysisJobs on column Valid
		CREATE NONCLUSTERED INDEX #IX_NewAnalysisJobs_Valid ON #TmpNewAnalysisJobs(Valid)


		-- Since SIC jobs can be required to only be imported if a Non-SIC job exists with the same dataset,
		-- we need to poll DMS twice, once for the Non-SIC jobs, and once for the SIC jobs
		If @AllowSIC = 1
			Set @MaxLoopCount = 2
		Else
			Set @MaxLoopCount = 1

		-- However, if any jobs are defined in @JobListOverride then set @MaxLoopCount to 1
		If @UsingJobListOverride = 1
			Set @MaxLoopCount = 1
	
		Set @LoopCount = 0
		While @LoopCount < @MaxLoopCount
		Begin
		
			If @LoopCount = 0
			Begin
				Set @CurrentLocation = 'Import job candidates: Non-SIC Jobs, plus jobs in @JobListOverride'
				
				-- Import Non-SIC Jobs and jobs in @JobListOverride if any are defined
				-- Note: The Protein_Collectionst_List values will be compared to the Protein_Collection_Filter values after the jobs have been tentatively added to #TmpNewAnalysisJobs (see below)
				Set @ResultTypeFilter = ' ResultType IN (SELECT Value FROM V_Import_Analysis_Result_Type_List) ' + @Lf + '  AND (ResultType <> ''SIC'')'

				Set @OrganismDBNameFilter = ' AND ((ProteinCollectionList <> ''na'' AND ProteinCollectionList <> '''')'
				If @FilterOnOrgDB = 1
					Set @OrganismDBNameFilter = @OrganismDBNameFilter + @Lf + ' OR OrganismDBName IN (SELECT Value FROM V_Import_Organism_DB_File_List))'
				Else
					Set @OrganismDBNameFilter = @OrganismDBNameFilter + ')'

				Set @SICDSFilter = ''
			End
			Else
			Begin
				Set @CurrentLocation = 'Import job candidates: SIC Jobs'
			
				-- Import SIC Jobs, optionally requiring that a dataset exist in #TmpNewAnalysisJobs or T_Analysis_Description
				Set @ResultTypeFilter = ' (ResultType = ''SIC'')'
				Set @OrganismDBNameFilter = ' '
				
				If @RequireExistingDatasetForNewSICJobs = 0
					Set @SICDSFilter = ''
				Else
				Begin
					Set @SICDSFilter = ''
					Set @SICDSFilter = @SICDSFilter + ' AND Dataset IN (SELECT DISTINCT Dataset FROM T_Analysis_Description'
					Set @SICDSFilter = @SICDSFilter +       ' UNION SELECT DISTINCT Dataset FROM #TmpNewAnalysisJobs)'
				End
			End


			-- Populate the temporary table with new jobs from DMS
			--
			Set @S = ''
			Set @S = @S + ' INSERT INTO #TmpNewAnalysisJobs'
			Set @S = @S +  ' (Job, Dataset, Dataset_ID, Experiment, Campaign, Organism,'
			Set @S = @S +  ' Instrument_Class, Instrument, Analysis_Tool, Parameter_File_Name,'
			Set @S = @S +  ' Organism_DB_Name, Protein_Collection_List, Protein_Options_List, Vol_Client, Vol_Server, Storage_Path,'
			Set @S = @S +  ' Dataset_Folder, Results_Folder, Settings_File_Name, Completed,'
			Set @S = @S +  ' ResultType, Enzyme_ID, Labelling, Separation_Sys_Type,'
			Set @S = @S +  ' PreDigest_Internal_Std, PostDigest_Internal_Std, Dataset_Internal_Std, Process_State) ' + @Lf
  			Set @S = @S + ' SELECT'
			Set @S = @S + '  Job, Dataset, DatasetID, Experiment, Campaign, Organism,' + @Lf
			Set @S = @S + '  InstrumentClass, InstrumentName, AnalysisTool, ParameterFileName,'  + @Lf
			Set @S = @S + '  OrganismDBName, ProteinCollectionList, ProteinOptions, StoragePathClient, StoragePathServer, '''' AS StoragePath,' + @Lf
			Set @S = @S + '  DatasetFolder, ResultsFolder, SettingsFileName, Completed,' + @Lf
			Set @S = @S + '  ResultType, EnzymeID, Labelling, SeparationSysType,' + @Lf
			Set @S = @S + '  [PreDigest Int Std], [PostDigest Int Std], [Dataset Int Std], 0 AS Process_State' + @Lf
			Set @S = @S + ' FROM ' + @JobInfoTable + ' DAJI' + @Lf
			
			If @UsingJobListOverride = 1
			Begin
				set @S = @S + ' INNER JOIN #T_Tmp_JobListOverride JobListQ ON DAJI.Job = JobListQ.JobOverride' + @Lf
			End

			Set @S = @S + ' WHERE Job NOT IN (SELECT Job FROM T_Analysis_Description) ' + @Lf

			If @UsingJobListOverride = 0
			Begin
				Set @S = @S + ' AND ( ' + @Lf
				Set @S = @S +   ' ' + @ResultTypeFilter + @Lf
				Set @S = @S +   '  AND Organism = ''' + @organism + '''' + @Lf

				If Len(@OrganismDBNameFilter) > 0
					Set @S = @S + ' ' + @OrganismDBNameFilter + @Lf

				If Len(@SICDSFilter) > 0
					Set @S = @S + ' ' + @SICDSFilter + @Lf
				
				if @FilterOnCampaign = 1
					Set @S = @S + '  AND Campaign IN (SELECT Value FROM T_Process_Config WHERE [Name] = ''Campaign'')' + @Lf

				if @FilterOnEnzymeID = 1
					Set @S = @S + ' AND EnzymeID IN (SELECT Value FROM T_Process_Config WHERE [Name] = ''Enzyme_ID'')' + @Lf
					
				if @campaignListCountExcluded > 0
				begin
					set @S = @S + '  AND NOT Campaign IN '
					set @S = @S + '( '
					set @S = @S + '	SELECT Campaign FROM #TmpCampaignsExcluded '
					set @S = @S + ')' + @Lf
				end
				
				if @expListCount > 0
				begin
					set @S = @S + '  AND Experiment IN '
					set @S = @S + '( '
					set @S = @S + '	SELECT Experiment FROM #TmpExperiments '
					set @S = @S + ')' + @Lf
				end
				
				if @expListCountExcluded > 0
				begin
					set @S = @S + '  AND NOT Experiment IN '
					set @S = @S + '( '
					set @S = @S + '	SELECT Experiment FROM #TmpExperimentsExcluded '
					set @S = @S + ')' + @Lf
				End

				set @S = @S + ' ) ' + @Lf
			End
			
			If @UsingJobListOverride = 0 And Len(@DateText) > 0
				set @S = @S + ' AND DS_Created >= ''' + @DateText + '''' + @Lf
				
			Set @S = @S + ' ORDER BY Job'
			
			If @PreviewSql <> 0
			Begin
				if @LoopCount = 0
				Begin
					if @UsingJobListOverride = 1
						Print '-- Sql to import jobs defined in @JobListOverride'
					else
						Print '-- Sql to import non-MASIC jobs (Note: this statement does not filter on Protein_Collection_List but the SP does when it calls ValidateNewAnalysesUsingProteinCollectionFilters)'
				End
				else
					Print '-- Sql to import MASIC jobs'
				Print @S + @CrLf
			End
				
			Exec (@S)
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error


			If @LoopCount = 0
			Begin -- <a>

				If @UsingJobListOverride = 1
				Begin
					---------------------------------------------------
					-- Update Valid to 1 for all jobs in #TmpNewAnalysisJobs
					---------------------------------------------------
					UPDATE #TmpNewAnalysisJobs
					SET Valid = 1
				End
				Else
				Begin
					---------------------------------------------------
					-- Update the jobs that do not use protein collections to have Valid = 1
					---------------------------------------------------
					UPDATE #TmpNewAnalysisJobs
					SET Valid = 1
					WHERE Protein_Collection_List = 'na' OR Protein_Collection_List = ''
					--
					SELECT @myRowCount = @@rowcount, @myError = @@error
				End

				-- Validate all jobs with Valid = 0 against the Protein Collection 
				--  filters defined in T_Process_Config
				Exec @myError = ValidateNewAnalysesUsingProteinCollectionFilters @PreviewSql, @message = @message output
				
				If @myError <> 0
					Goto Done
				
			End -- </a>


			If @PreviewSql <> 0
			Begin
				SELECT @myRowCount = Count(*)
				FROM #PreviewSqlData
				
				If @myRowCount > 0
				Begin
					SELECT * 
					FROM #PreviewSqlData
					ORDER BY Filter_Type, Value
				
					TRUNCATE TABLE #PreviewSqlData
				End
			End

			Set @LoopCount = @LoopCount + 1
		End

		---------------------------------------------------
		-- Examine the temporary table to find new datasets
		-- Need to add the datasets to T_Datasets before populating T_Analysis_Description
		---------------------------------------------------
		--
		Set @CurrentLocation = 'Look for new datasets'
		
		If @infoOnly = 0
		begin
			-- Add any new datasets to T_Datasets
			-- We'll lookup Type, Created_DMS, and the additional info below
			INSERT INTO T_Datasets (Dataset_ID, Dataset, Created, Dataset_Process_State)
			SELECT TAD.Dataset_ID, TAD.Dataset, GetDate() AS Created, @NextProcessState AS Process_State
			FROM #TmpNewAnalysisJobs AS TAD
				LEFT OUTER JOIN T_Datasets ON TAD.Dataset_ID = T_Datasets.Dataset_ID
			WHERE T_Datasets.Dataset_ID IS NULL
			GROUP BY TAD.Dataset_ID, TAD.Dataset
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			
			Set @DatasetsAdded = @myRowCount
			
			If @myError <> 0
			Begin
				Set @message = 'Error adding new datasets to T_Datasets: ' + convert(varchar(9), @myError)
				If @infoOnly = 0 
					execute PostLogEntry 'Error', @message, 'ImportNewPeptideAnalyses'
			End
			
			If @DatasetsAdded > 0
			Begin
				-- Lookup the additional stats for the new datasets
				Set @S = ''
				Set @S = @S + ' UPDATE T_Datasets'
				Set @S = @S + ' SET Type = DDI.Type,'
				Set @S = @S +      ' Created_DMS = DDI.Created,'
				Set @S = @S +      ' Acq_Time_Start = DDI.[Acquisition Start],'
				Set @S = @S +      ' Acq_Time_End = DDI.[Acquisition End],'
				Set @S = @S +      ' Scan_Count = DDI.[Scan Count]'
				Set @S = @S + ' FROM ' + @DatasetInfoTable + ' AS DDI INNER JOIN '
				Set @S = @S +        ' T_Datasets ON T_Datasets.Dataset_ID = DDI.ID'
				Set @S = @S + ' WHERE T_Datasets.Created_DMS Is Null'
				--
				Exec (@S)
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

		-- Update the Process_State values in #TmpNewAnalysisJobs
		UPDATE #TmpNewAnalysisJobs
		SET Process_State = @NextProcessState
		FROM #TmpNewAnalysisJobs INNER JOIN 
			#T_ResultTypeList ON #TmpNewAnalysisJobs.ResultType = #T_ResultTypeList.ResultType
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
		Set @entriesAdded = @myRowCount
		
		---------------------------------------------------
		-- Now populate T_Analysis_Description with the jobs in #TmpNewAnalysisJobs
		---------------------------------------------------
		--
		Set @CurrentLocation = 'Populate T_Analysis_Description'
		
		Set @S = ''

		if @infoOnly = 0
		begin	
			Set @S = @S + ' INSERT INTO T_Analysis_Description'
			Set @S = @S + ' (Job, Dataset, Dataset_ID, Experiment, Campaign, Organism,'
			Set @S = @S + ' Instrument_Class, Instrument, Analysis_Tool, Parameter_File_Name,'
			Set @S = @S + ' Organism_DB_Name, Protein_Collection_List, Protein_Options_List,'
			Set @S = @S + ' Vol_Client, Vol_Server, Storage_Path,'
			Set @S = @S + ' Dataset_Folder, Results_Folder, Settings_File_Name,'
			Set @S = @S + ' Completed, ResultType, Enzyme_ID, Labelling, Separation_Sys_Type,'
			Set @S = @S + ' PreDigest_Internal_Std, PostDigest_Internal_Std, Dataset_Internal_Std,'
			Set @S = @S + ' Created, Process_State, Last_Affected)'
		end
  		Set @S = @S + ' SELECT'
		Set @S = @S + '  Job, AJ.Dataset, AJ.Dataset_ID, Experiment, Campaign, Organism,' + @Lf
		Set @S = @S + '  Instrument_Class, AJ.Instrument, Analysis_Tool, Parameter_File_Name,'  + @Lf
		Set @S = @S + '  Organism_DB_Name, Protein_Collection_List, Protein_Options_List,' + @Lf
		Set @S = @S + '  Vol_Client, Vol_Server, Storage_Path,' + @Lf
		Set @S = @S + '  Dataset_Folder, Results_Folder, Settings_File_Name,' + @Lf
		Set @S = @S + '  Completed, ResultType, Enzyme_ID, Labelling, Separation_Sys_Type,' + @Lf
		Set @S = @S + '  PreDigest_Internal_Std, PostDigest_Internal_Std, Dataset_Internal_Std,' + @Lf
		Set @S = @S + '  GetDate() AS Created, Process_State, GetDate() AS Last_Affected' + @Lf
		Set @S = @S + ' FROM #TmpNewAnalysisJobs as AJ' + @Lf
		if @infoOnly = 0
		begin
			Set @S = @S + ' INNER JOIN T_Datasets ON AJ.Dataset_ID = T_Datasets.Dataset_ID' + @Lf
		end
		Set @S = @S + ' WHERE AJ.Job NOT IN (SELECT Job FROM T_Analysis_Description)' + @Lf
		Set @S = @S + ' ORDER BY Job'

		If @PreviewSql <> 0
		Begin
			print '-- Sql to copy data from #TmpNewAnalysisJobs to T_Analysis_Description'
			Print @S + @CrLf
		End
		Exec (@S)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
		Set @entriesAdded = @myRowCount
		
		Set @MissingParamFileCount = 0
		if @infoOnly = 0 And @entriesAdded > 0
		begin
			-- Verify that the inserted Jobs have param files that are defined in MT_Main.dbo.V_DMS_Param_Files
			--
			Set @CurrentLocation = 'Validate parameter files for new analysis jobs'

			-- Make sure MT_Main.dbo.V_DMS_Param_Files actually has been populated; if it hasn't, 
			--  then all of the newly imported jobs need to be set at state 4
			
			Set @MatchCount = 0
			SELECT @MatchCount = COUNT(*)
			FROM MT_Main.dbo.V_DMS_Param_Files
			
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
						Parameter_File_Name NOT IN (SELECT DISTINCT Param_File_Name FROM MT_Main.dbo.V_DMS_Param_Files)
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			
			Set @MissingParamFileCount = @myRowCount
		end

	
		-- Post the log entry messages
		Set @CurrentLocation = 'Post the log entry messages'
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
			
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'ImportNewPeptideAnalyses')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch
	
Done:
	Return @myError


GO
