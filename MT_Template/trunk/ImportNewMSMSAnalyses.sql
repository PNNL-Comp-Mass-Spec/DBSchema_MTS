/****** Object:  StoredProcedure [dbo].[ImportNewMSMSAnalyses] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ImportNewMSMSAnalyses
/****************************************************
**
**	Desc: Imports entries from the analysis job table
**        in the associated peptide database and inserts them
**        into the local analysis description table
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**	Auth:	grk
**	Date:	11/13/2001
**			11/05/2003 grk - Modified dynamic SQL to use new import criteria tables
**			09/20/2004 mem - Modified to use T_Process_Config and additional import criteria, to allow multiple Campaigns, and to allow multiple Peptide DBs
**			09/22/2004 mem - Added ability to handle Experiment filter parameters in T_Process_Config that contain a wildcard character (percent sign)
**			09/24/2004 mem - Added ability to handle Experiment_Exclusion filter parameters in T_Process_Config
**			10/01/2004 mem - Added ability to handle Dataset and Dataset_Exclusion filter parameters
**			11/27/2004 mem - Added column GANET_RSquared
**			01/22/2005 mem - Added ScanTime_NET columns
**			03/07/2005 mem - Now checking for no matching Experiments if an experiment inclusion filter is defined; also checking for no matching datasets if a dataset inclusion filter is defined
**			04/06/2005 mem - Added ability to handle Campaign_and_Experiment filter parameter in T_Process_Config
**			04/25/2005 mem - Added parameter @JobListOverride
**			07/07/2005 mem - Now populating column Instrument
**			07/08/2005 mem - Now populating column Internal_Standard
**			07/18/2005 mem - Now populating column Labelling; also, switched location of Instrument from T_Datasets to T_Analysis_Description
**			09/03/2005 mem - Now populating column Dataset_SIC_Job
**			11/10/2005 mem - Now populating columns Dataset_Acq_Time_Start, Dataset_Acq_Time_End, and Dataset_Scan_Count
**			11/30/2005 mem - Added brackets around @peptideDBName as needed to allow for DBs with dashes in the name
**						   - Added parameter @PreviewSql
**			12/01/2005 mem - Increased size of @peptideDBName from 64 to 128 characters
**			12/11/2005 mem - Added support for XTandem results by reading field MSMS_Result_Type from T_Process_Config
**			12/15/2005 mem - Now populating T_Analysis_Description with PreDigest_Internal_Std, PostDigest_Internal_Std, and Dataset_Internal_Std (previously named Internal_Standard)
**			02/23/2006 mem - Updated this SP to post a message to the log if new entries are added rather than having the calling procedure do so
**			02/27/2006 mem - Updated to only consider the jobs in @JobListOverride if defined; previously, would still add jobs passing the default filters even if @JobListOverride contained one or more jobs
**			03/02/2006 mem - Fixed bug that was posting a log entry when @infoOnly = 1 rather than when @infoOnly = 0
**			03/07/2006 mem - Added support for Enzyme_ID in T_Process_Config
**			03/09/2006 mem - Renamed field Created to Created_Peptide_DB in T_Analysis_Description
**			06/04/2006 mem - Now populating T_Analysis_Description with Protein_Collection_List and Protein_Options_List; additionally, applying the OrganismDBName filter to ProteinCollectionList
**			06/10/2006 mem - Added support for Protein_Collection_Filter, Seq_Direction_Filter, and Protein_Collection_and_Protein_Options_Combo in T_Process_Config
**			06/13/2006 mem - Updated to recognize Protein_Collection_List jobs by only testing the Protein_Collection_List field in the source tablet for 'na' or '' rather than also testing the Organism_DB_Name field
**			08/01/2006 mem - Increased size of @JobListOverride and switched to use udfParseDelimitedList to parse the list
**
*****************************************************/
(
	@entriesAdded int = 0 output,
	@message varchar(512) = '' output,
	@infoOnly int = 0,
	@JobListOverride varchar(4096) = '',
	@PreviewSql tinyint = 0					-- Set to 1 to display the table population Sql statements; if this is 1, then forces @infoOnly to be 1
)
As
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @result int
	set @result = 0
		
	declare @startingSize int
	declare @endingSize int

	declare @peptideDBName varchar(128)
	set @peptideDBName = ''

	declare @peptideDBID int
	declare @MissingPeptideDB tinyint

	declare @SCampaign varchar(255)
	declare @SAddnl varchar(2000)
	declare @SCampaignAndAddnl varchar(2000)

	declare @S varchar(8000)
	declare @continue tinyint

	declare @filterValueLookupTableName varchar(256)
	declare @filterMatchCount int

	declare @FilterOnEnzymeID tinyint
	
	declare @UsingJobListOverride tinyint
	set @UsingJobListOverride =0
	
	declare @JobsByDualKeyFilters int
	
	declare @expListCount int
	declare @expListCountExcluded int
	
	declare @datasetListCount int
	declare @datasetListCountExcluded int

	declare @MatchCount int

	declare @CrLf char(2)
	Set @CrLf = char(10) + char(13)

	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------
	--
	set @entriesAdded = 0
	set @message = ''
	Set @JobListOverride = LTrim(RTrim(IsNull(@JobListOverride, '')))

	Set @PreviewSql = IsNull(@PreviewSql, 0)
	If @PreviewSql <> 0
		Set @infoOnly = 1

	---------------------------------------------------
	-- Make sure at least one campaign is defined for this mass tag database
	---------------------------------------------------
	--
	declare @campaign varchar(128)
	set @campaign = ''
	--
	SELECT TOP 1 @campaign = Value
	FROM T_Process_Config
	WHERE [Name] IN ('Campaign', 'Campaign_and_Experiment') AND Len(Value) > 0
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myRowCount < 1 OR @campaign = ''
	begin
		set @myError = 40001
		goto Done
	end
	
	---------------------------------------------------
	-- Create several temporary tables
	---------------------------------------------------
	--
	CREATE TABLE #T_Peptide_Database_List (
		PeptideDBName varchar(128) NOT NULL
	)

	CREATE TABLE #TmpFilterList (
		Value varchar(128)
	)
	
	CREATE TABLE #TmpExperiments (
		Experiment varchar(128)
	)

	CREATE TABLE #TmpExperimentsExcluded (
		Experiment varchar(128)
	)

	CREATE TABLE #TmpDatasets (
		Dataset varchar(128)
	)

	CREATE TABLE #TmpDatasetsExcluded (
		Dataset varchar(128)
	)

	CREATE TABLE #TmpJobsByDualKeyFilters (
		Job int
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
		SELECT Convert(int, Value)
		FROM dbo.udfParseDelimitedList(@JobListOverride, ',')
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
	End
	
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
	-- Get peptide database name(s)
	---------------------------------------------------
	--
	INSERT INTO #T_Peptide_Database_List (PeptideDBName)
	SELECT Value
	FROM T_Process_Config
	WHERE [Name] = 'Peptide_DB_Name' AND Len(Value) > 0
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myRowCount < 1
	begin
		set @message = 'No peptide databases are defined in T_Process_Config'
		set @myError = 40000
		goto Done
	end

	---------------------------------------------------
	-- Count number of Enzyme_ID entries in T_Process_Config
	---------------------------------------------------
	--
	Set @filterMatchCount = 0
	SELECT @filterMatchCount = COUNT(*)
	FROM T_Process_Config
	WHERE [Name] = 'Enzyme_ID'
	--
	If @filterMatchCount > 0
		Set	@FilterOnEnzymeID = 1
	Else
		Set @FilterOnEnzymeID = 0


	---------------------------------------------------
	-- Get minimum GANET Fit threshold for this database
	-- The minimum GANET fit has typically been replaced
	--  with minimum R-Squared; so the 'GANET_Fit_Minimum_Import'
	--  entry may not be present in T_Process_Config
	---------------------------------------------------
	--
	declare @minGANETFit float
	set @minGANETFit = -1
	--
	SELECT @minGANETFit = Value
	FROM T_Process_Config
	WHERE [Name] = 'GANET_Fit_Minimum_Import' AND Len(Value) > 0
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Could not get minimum GANET fit (parameter GANET_Fit_Minimum_Import) in T_Process_Config'
		set @myError = 40002
		goto Done
	end

	---------------------------------------------------
	-- Attempt to read the minimum R-Squared value
	---------------------------------------------------
	declare @minGANETRSquared float
	set @minGANETRSquared = -1
	--
	SELECT @minGANETRSquared = Value
	FROM T_Process_Config
	WHERE [Name] = 'GANET_RSquared_Minimum_Import' AND Len(Value) > 0
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Could not get minimum GANET R-Squared (parameter GANET_RSquared_Minimum_Import) in T_Process_Config'
		set @myError = 40003
		goto Done
	end

	-- Minimum R-Squared, if present, takes precedence over Minimum Fit
	If @minGANETRSquared >=0
		Set @minGANETFit = -1
	
	if @minGANETFit = -1 AND @minGANETRSquared = -1
	Begin
		set @message = 'Could not get minimum GANET Fit or R-Squared (parameter GANET_Fit_Minimum_Import or GANET_RSquared_Minimum_Import) in T_Process_Config'
		set @myError = 40004
		goto Done
	End

	---------------------------------------------------
	-- Construct the Campaign Sql, plus the Process_State, Organism_DB_Name, Parameter_File_Name, Separation_Sys_Type, and Result_Type Sql
	---------------------------------------------------
	set @SCampaign = ''
	set @SCampaign = @SCampaign + ' Campaign IN ('
	set @SCampaign = @SCampaign +   ' SELECT Value FROM T_Process_Config'
	set @SCampaign = @SCampaign +   ' WHERE [Name] = ''Campaign'' AND Len(Value) > 0)'
	
	set @SAddnl = ''
	set @SAddnl = @SAddnl + ' (Process_State = 70)'
	
	If @minGANETFit >= 0
		set @SAddnl = @SAddnl + ' AND (ISNULL(GANET_Fit, 0) >= ' + convert(varchar(12), @minGANETFit) + ')'  
	Else
		set @SAddnl = @SAddnl + ' AND (ISNULL(GANET_RSquared, 0) >= ' + convert(varchar(12), @minGANETRSquared) + ')'  
		
	set @SAddnl = @SAddnl + ' AND ((Protein_Collection_List <> ''na'' AND Protein_Collection_List <> '''')'
	set @SAddnl = @SAddnl +      ' OR Organism_DB_Name IN (SELECT Value FROM T_Process_Config'
	set @SAddnl = @SAddnl +      ' WHERE [Name] = ''Organism_DB_File_Name'' AND Len(Value) > 0)'
	set @SAddnl = @SAddnl +  ')'

	set @SAddnl = @SAddnl + ' AND Parameter_File_Name IN (SELECT Value FROM T_Process_Config'
	set @SAddnl = @SAddnl +     ' WHERE [Name] = ''Parameter_File_Name'' AND Len(Value) > 0)'

	set @SAddnl = @SAddnl + ' AND Separation_Sys_Type IN (SELECT Value FROM T_Process_Config'
	set @SAddnl = @SAddnl +     ' WHERE [Name] = ''Separation_Type'' AND Len(Value) > 0)'

	set @SAddnl = @SAddnl + ' AND ResultType IN (SELECT Value FROM T_Process_Config'
	set @SAddnl = @SAddnl +     ' WHERE [Name] = ''MSMS_Result_Type'' AND Len(Value) > 0)'

	if @FilterOnEnzymeID = 1
	Begin
		Set @SAddnl = @SAddnl + ' AND Enzyme_ID IN (SELECT Value FROM T_Process_Config'
		Set @SAddnl = @SAddnl +     ' WHERE [Name] = ''Enzyme_ID'' AND Len(Value) > 0)'
	End

	-- Combine the Campaign filter with the additional filters
	set @SCampaignAndAddnl = @SCampaign + ' AND ' + @SAddnl	
	
	---------------------------------------------------
	-- Import analyses from peptide database(s)
	---------------------------------------------------
	--
	-- get entries from the analysis job table in the linked 
	-- peptide database(s) that meet selection criteria

	-- Create a temporary table to hold the new jobs since we may need to perform additional filtering after populating this table

	if exists (select * from dbo.sysobjects where id = object_id(N'[#TmpNewAnalysisJobs]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table [#TmpNewAnalysisJobs]

	CREATE TABLE #TmpNewAnalysisJobs (
		[Job] [int] NOT NULL,
		[Dataset] [varchar] (128) NOT NULL,
		[Dataset_ID] [int] NOT NULL,
		[Dataset_Created_DMS] [datetime] NULL,
		[Dataset_Acq_Time_Start] [datetime] NULL,
		[Dataset_Acq_Time_End] [datetime] NULL,
		[Dataset_Scan_Count] [int] NULL,
		[Experiment] [varchar] (64) NULL,
		[Campaign] [varchar] (64) NULL,
		[PDB_ID] [int] NULL,
		[Dataset_SIC_Job] [int] NULL,
		[Organism] [varchar] (50) NOT NULL,
		[Instrument_Class] [varchar] (32) NOT NULL,
		[Instrument] [varchar] (64) NULL,
		[Analysis_Tool] [varchar] (64) NOT NULL,
		[Parameter_File_Name] [varchar] (255) NOT NULL,
		[Settings_File_Name] [varchar] (255) NULL,
		[Organism_DB_Name] [varchar] (64) NOT NULL,
		[Protein_Collection_List] [varchar] (2048) NOT NULL,
		[Protein_Options_List] [varchar] (256) NOT NULL,
		[Vol_Client] [varchar] (128) NOT NULL,
		[Vol_Server] [varchar] (128) NULL,
		[Storage_Path] [varchar] (255) NOT NULL,
		[Dataset_Folder] [varchar] (128) NOT NULL,
		[Results_Folder] [varchar] (128) NOT NULL,
		[Completed] [datetime] NULL,
		[ResultType] [varchar] (32) NULL,
		[Separation_Sys_Type] [varchar] (50) NULL,
		[PreDigest_Internal_Std] [varchar] (50) NULL,
		[PostDigest_Internal_Std] [varchar] (50) NULL,
		[Dataset_Internal_Std] [varchar] (50) NULL,
		[Enzyme_ID] [int] NULL,
		[Labelling] [varchar] (64) NULL,
		[Created_Peptide_DB] [datetime] NOT NULL,
		[State] [int] NOT NULL,
		[GANET_Fit] [float] NULL,
		[GANET_Slope] [float] NULL,
		[GANET_Intercept] [float] NULL,
		[GANET_RSquared] [real] NULL,
		[ScanTime_NET_Slope] [real] NULL,
		[ScanTime_NET_Intercept] [real] NULL,
		[ScanTime_NET_RSquared] [real] NULL,
		[ScanTime_NET_Fit] [real] NULL,
		[Valid] tinyint NOT NULL DEFAULT (0)
	) ON [PRIMARY]

	-- Add an index to #TmpNewAnalysisJobs on column Job
	CREATE CLUSTERED INDEX #IX_NewAnalysisJobs_Job ON #TmpNewAnalysisJobs(Job)

	-- Add an index to #TmpNewAnalysisJobs on column Valid
	CREATE NONCLUSTERED INDEX #IX_NewAnalysisJobs_Valid ON #TmpNewAnalysisJobs(Valid)
	
	-- Record the number of jobs currently present in the analysis description table
	--
	SELECT @startingSize = COUNT(*) 
	FROM T_Analysis_Description
	

	-- Loop through peptide database(s) and insert analyses jobs
	--
	Set @continue = 1
	While @continue = 1
	Begin -- <PepDB>
		SELECT TOP 1 @peptideDBName = PeptideDBName
		FROM #T_Peptide_Database_List
		ORDER BY PeptideDBName
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin -- <a>

			-- Lookup the PDB_ID value for @peptideDBName in MT_Main
			--
			Set @peptideDBID = 0
			SELECT @peptideDBID = PDB_ID
			FROM MT_Main.dbo.T_Peptide_Database_List
			WHERE PDB_Name = @peptideDBName
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			If @myRowCount = 0
				Set @MissingPeptideDB = 1
			Else
				Set @MissingPeptideDB = 0
			

			---------------------------------------------------
			-- Define the table where we will look up jobs from
			---------------------------------------------------
			set @filterValueLookupTableName = '[' + @peptideDBName + '].dbo.T_Analysis_Description'

			---------------------------------------------------
			-- Clear the #TmpNewAnalysisJobs and the filter tables
			---------------------------------------------------
			TRUNCATE TABLE #TmpNewAnalysisJobs
			TRUNCATE TABLE #TmpJobsByDualKeyFilters
			TRUNCATE TABLE #TmpExperiments
			TRUNCATE TABLE #TmpExperimentsExcluded
			TRUNCATE TABLE #TmpDatasets
			TRUNCATE TABLE #TmpDatasetsExcluded

			---------------------------------------------------
			-- Populate #TmpJobsByDualKeyFilters using jobs that match
			-- experiments specified by Campaign_and_Experiment entries
			-- in T_Process_Config
			---------------------------------------------------

			set @JobsByDualKeyFilters = 0
			
			set @filterMatchCount = 0
			Exec @myError = ParseFilterListDualKey 'Campaign_and_Experiment', @filterValueLookupTableName, 'Campaign', 'Experiment', 'Job', @SAddnl, @filterMatchCount OUTPUT
			--
			if @myError <> 0
			begin
				set @message = 'Error looking up matching jobs by Campaign and Experiment'
				set @myError = 40002
				goto Done
			end
			Else
			begin
				INSERT INTO #TmpJobsByDualKeyFilters (Job)
				SELECT Convert(int, Value)
				FROM #TmpFilterList
				--
				SELECT @myError = @@error, @JobsByDualKeyFilters = @@rowcount
				
				If @PreviewSql <> 0
					INSERT INTO #PreviewSqlData (Filter_Type, Value)
					SELECT 'Jobs matching Campaign/Experiment dual filter', Convert(varchar(18), Job)
					FROM #TmpJobsByDualKeyFilters
			End

			
			---------------------------------------------------
			-- See if any experiments are defined in T_Process_Config
			-- Populate #TmpExperiments with list of experiment names
			-- If any contain a percent sign, then use that as a matching
			--  parameter to populate #TmpExperiments
			---------------------------------------------------
			--
			set @expListCount = 0
			set @filterMatchCount = 0
			Exec @myError = ParseFilterList 'Experiment', @filterValueLookupTableName, 'Experiment', @SCampaignAndAddnl, @filterMatchCount OUTPUT
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
				SELECT @myError = @@error, @expListCount = @@rowcount

				If @expListCount = 0 And @filterMatchCount > 0
				Begin
					-- The user defined an experiment inclusion filter containing a %, but none matched
					-- Add a bogus entry to #TmpExperiments to guarantee that no jobs will match
					INSERT INTO #TmpExperiments (Experiment)
					VALUES ('FakeExperiment_' + Convert(varchar(64), NewId()))
					--
					SELECT @myError = @@error, @expListCount = @@rowcount			
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
			Exec @myError = ParseFilterList 'Experiment_Exclusion', @filterValueLookupTableName, 'Experiment', @SCampaignAndAddnl
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
				SELECT @myError = @@error, @expListCountExcluded = @@rowcount

				If @PreviewSql <> 0
					INSERT INTO #PreviewSqlData (Filter_Type, Value)
					SELECT 'Experiment Exclusion', Experiment 
					FROM #TmpExperimentsExcluded
			End


			---------------------------------------------------
			-- See if any datasets are defined in T_Process_Config
			-- Populate #TmpDatasets with list of dataset names
			---------------------------------------------------
			--
			set @datasetListCount = 0
			set @filterMatchCount = 0
			Exec @myError = ParseFilterList 'Dataset', @filterValueLookupTableName, 'Dataset', @SCampaignAndAddnl, @filterMatchCount OUTPUT
			--
			if @myError <> 0
			begin
				set @message = 'Error looking up dataset inclusion filter names'
				set @myError = 40008
				goto Done
			end
			Else
			begin
				INSERT INTO #TmpDatasets (Dataset)
				SELECT Value FROM #TmpFilterList
				--
				SELECT @myError = @@error, @datasetListCount = @@rowcount

				If @datasetListCount = 0 And @filterMatchCount > 0
				Begin
					-- The user defined a dataset inclusion filter containing a %, but none matched
					-- Add a bogus entry to #TmpDatasets to guarantee that no jobs will match
					INSERT INTO #TmpDatasets (Dataset)
					VALUES ('FakeDataset_' + Convert(varchar(64), NewId()))
					--
					SELECT @myError = @@error, @datasetListCount = @@rowcount			
				End

				If @PreviewSql <> 0
					INSERT INTO #PreviewSqlData (Filter_Type, Value)
					SELECT 'Dataset Inclusion', Dataset 
					FROM #TmpDatasets
			End


			---------------------------------------------------
			-- See if any excluded datasets are defined in T_Process_Config
			-- Populate #TmpDatasetsExcluded with list of dataset names
			---------------------------------------------------
			--
			set @datasetListCountExcluded = 0
			Exec @myError = ParseFilterList 'Dataset_Exclusion', @filterValueLookupTableName, 'Dataset', @SCampaignAndAddnl
			--
			if @myError <> 0
			begin
				set @message = 'Error looking up dataset exclusion filter names'
				set @myError = 40009
				goto Done
			end
			Else
			begin
				INSERT INTO #TmpDatasetsExcluded (Dataset)
				SELECT Value FROM #TmpFilterList
				--
				SELECT @myError = @@error, @datasetListCountExcluded = @@rowcount

				If @PreviewSql <> 0
					INSERT INTO #PreviewSqlData (Filter_Type, Value)
					SELECT 'Dataset Exclusion', Dataset 
					FROM #TmpDatasetsExcluded
			End


			---------------------------------------------------
			-- Construct the Sql to populate T_Analysis_Description
			---------------------------------------------------
			
			set @S = ''

			set @S = @S + 'INSERT INTO #TmpNewAnalysisJobs ('
			set @S = @S + ' Job, Dataset, Dataset_ID,'
			set @S = @S + ' Dataset_Created_DMS, Dataset_Acq_Time_Start, Dataset_Acq_Time_End, Dataset_Scan_Count,'
			set @S = @S + ' Experiment, Campaign, PDB_ID,'
			set @S = @S + ' Dataset_SIC_Job, Organism, Instrument_Class, Instrument, Analysis_Tool,'
			set @S = @S + ' Parameter_File_Name, Settings_File_Name,'
			set @S = @S + ' Organism_DB_Name, Protein_Collection_List, Protein_Options_List,'
			set @S = @S + ' Vol_Client, Vol_Server, Storage_Path, Dataset_Folder, Results_Folder,'
			set @S = @S + ' Completed, ResultType, Separation_Sys_Type,'
			set @S = @S + ' PreDigest_Internal_Std, PostDigest_Internal_Std, Dataset_Internal_Std,'
			set @S = @S + ' Enzyme_ID, Labelling, Created_Peptide_DB, State, '
			set @S = @S + ' GANET_Fit, GANET_Slope, GANET_Intercept, GANET_RSquared,'
			set @S = @S + ' ScanTime_NET_Slope, ScanTime_NET_Intercept, ScanTime_NET_RSquared, ScanTime_NET_Fit'
			set @S = @S + ') '
			set @S = @S + 'SELECT DISTINCT * '
			set @S = @S + 'FROM ('
			set @S = @S + 'SELECT '
			set @S = @S + '	PT.Job, PT.Dataset, PT.Dataset_ID,'
			set @S = @S + ' DS.Created_DMS, DS.Acq_Time_Start, DS.Acq_Time_End, DS.Scan_Count,'
			set @S = @S + '	PT.Experiment, PT.Campaign, ' + Convert(varchar(11), @peptideDBID) + ' AS PDB_ID,'
			set @S = @S + ' DS.SIC_Job, PT.Organism, PT.Instrument_Class, PT.Instrument, PT.Analysis_Tool,'
			set @S = @S + '	PT.Parameter_File_Name,	PT.Settings_File_Name,'
			set @S = @S + '	PT.Organism_DB_Name, PT.Protein_Collection_List, PT.Protein_Options_List,'
			set @S = @S + '	PT.Vol_Client, PT.Vol_Server, PT.Storage_Path, PT.Dataset_Folder, PT.Results_Folder,'
			set @S = @S + '	PT.Completed, PT.ResultType, PT.Separation_Sys_Type,'
			set @S = @S + ' PT.PreDigest_Internal_Std, PT.PostDigest_Internal_Std, PT.Dataset_Internal_Std,'
			set @S = @S + '	PT.Enzyme_ID, PT.Labelling, PT.Created, 1 AS StateNew,'
			set @S = @S + '	PT.GANET_Fit, PT.GANET_Slope, PT.GANET_Intercept, PT.GANET_RSquared,'
			set @S = @S + '	ScanTime_NET_Slope, ScanTime_NET_Intercept, ScanTime_NET_RSquared, ScanTime_NET_Fit '
			set @S = @S + 'FROM '
			set @S = @S +   '[' + @peptideDBName + '].dbo.T_Analysis_Description AS PT LEFT OUTER JOIN '
			set @S = @S +   '[' + @peptideDBName + '].dbo.T_Datasets AS DS ON PT.Dataset_ID = DS.Dataset_ID '

			If @UsingJobListOverride = 1
			Begin
				set @S = @S + ' INNER JOIN #T_Tmp_JobListOverride JobListQ ON PT.Job = JobListQ.JobOverride'
			End
			Else			
			Begin
				set @S = @S + ' WHERE ('
					set @S = @S + @SCampaignAndAddnl
					
					if @expListCount > 0
					begin
						set @S = @S + 'AND PT.Experiment IN '
						set @S = @S + '( '
						set @S = @S + '	SELECT Experiment FROM #TmpExperiments '
						set @S = @S + ') '
					end
					
					if @expListCountExcluded > 0
					begin
						set @S = @S + 'AND NOT PT.Experiment IN '
						set @S = @S + '( '
						set @S = @S + '	SELECT Experiment FROM #TmpExperimentsExcluded '
						set @S = @S + ') '
					End

					if @datasetListCount > 0
					begin
						set @S = @S + 'AND PT.Dataset IN '
						set @S = @S + '( '
						set @S = @S + '	SELECT Dataset FROM #TmpDatasets '
						set @S = @S + ') '
					end

					if @datasetListCountExcluded > 0
					begin
						set @S = @S + 'AND NOT PT.Dataset IN '
						set @S = @S + '( '
						set @S = @S + '	SELECT Dataset FROM #TmpDatasetsExcluded '
						set @S = @S + ') '
					end
				set @S = @S + ')'
					
				-- Now add jobs found using the alternate job selection method
				If @JobsByDualKeyFilters > 0
				Begin
					set @S = @S + ' OR (Job IN (SELECT Job FROM #TmpJobsByDualKeyFilters)) '
				End
			End
			
			set @S = @S + ') As LookupQ'
			set @S = @S + ' WHERE Job NOT IN (SELECT Job FROM T_Analysis_Description)'
			
			If @UsingJobListOverride = 0 And Len(@DateText) > 0
				set @S = @S + ' AND Created_DMS >= ''' + @DateText + ''''
				
			set @S = @S +  ' ORDER BY Job'

			If @PreviewSql <> 0
			Begin
				Print '-- Sql used to import new MS/MS analyses from "' + @peptideDBName + '"'
				Print @S + @CrLf
			End
			--			
			exec (@S)
			--
			SELECT @myError = @result, @myRowcount = @@rowcount
			--
			if @myError  <> 0
			begin
				set @message = 'Could not execute import dynamic SQL'
				set @myError = 40010
				goto Done
			end

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


			-- Count the number of jobs present in #TmpNewAnalysisJobs
			SELECT @MatchCount = COUNT(*)
			FROM #TmpNewAnalysisJobs

			If @MatchCount > 0
			Begin
				If @infoOnly = 0
					-- Copy the new jobs from #TmpNewAnalysisJobs to T_Analysis_Description
					INSERT INTO T_Analysis_Description (
						Job, Dataset, Dataset_ID, Dataset_Created_DMS, 
						Dataset_Acq_Time_Start, Dataset_Acq_Time_End, Dataset_Scan_Count, 
						Experiment, Campaign, PDB_ID, Dataset_SIC_Job, 
						Organism, Instrument_Class, Instrument, 
						Analysis_Tool, Parameter_File_Name, Settings_File_Name, 
						Organism_DB_Name, Protein_Collection_List, Protein_Options_List, 
						Vol_Client, Vol_Server, Storage_Path, Dataset_Folder, Results_Folder, 
						Completed, ResultType, Separation_Sys_Type, 
						PreDigest_Internal_Std, PostDigest_Internal_Std, 
						Dataset_Internal_Std, Enzyme_ID, Labelling, Created_Peptide_DB,
						GANET_Fit, GANET_Slope, GANET_Intercept, GANET_RSquared, ScanTime_NET_Slope, 
						ScanTime_NET_Intercept, ScanTime_NET_RSquared, ScanTime_NET_Fit
						)				
					SELECT 
						Job, Dataset, Dataset_ID, Dataset_Created_DMS, 
						Dataset_Acq_Time_Start, Dataset_Acq_Time_End, Dataset_Scan_Count, 
						Experiment, Campaign, PDB_ID, Dataset_SIC_Job, 
						Organism, Instrument_Class, Instrument, 
						Analysis_Tool, Parameter_File_Name, Settings_File_Name, 
						Organism_DB_Name, Protein_Collection_List, Protein_Options_List, 
						Vol_Client, Vol_Server, Storage_Path, Dataset_Folder, Results_Folder, 
						Completed, ResultType, Separation_Sys_Type, 
						PreDigest_Internal_Std, PostDigest_Internal_Std, 
						Dataset_Internal_Std, Enzyme_ID, Labelling, Created_Peptide_DB,
						GANET_Fit, GANET_Slope, GANET_Intercept, GANET_RSquared, ScanTime_NET_Slope, 
						ScanTime_NET_Intercept, ScanTime_NET_RSquared, ScanTime_NET_Fit
					FROM #TmpNewAnalysisJobs 
				Else
					SELECT *
					FROM #TmpNewAnalysisJobs
					ORDER BY Job
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
				
				Set @entriesAdded = @entriesAdded + @myRowCount
				
				IF @myRowCount > 0 and @infoOnly = 0 And @MissingPeptideDB = 1
				Begin
					-- New jobs were added, but the Peptide DB was unknown
					-- Post an entry to the log, but do not return an error
					Set @message = 'Peptide database ' + @peptideDBName + ' was not found in MT_Main.dbo.T_Peptide_Database_List; newly imported Jobs have been assigned a PDB_ID value of 0'
					execute PostLogEntry 'Error', @message, 'ImportNewMSMSAnalyses'
					Set @message = ''
				End
			End
					
			DELETE FROM #T_Peptide_Database_List
			WHERE PeptideDBName = @peptideDBName
			
			If @PreviewSql <> 0
			Begin
				SELECT @MatchCount = Count(*)
				FROM #PreviewSqlData
				
				If @MatchCount > 0
				Begin
					SELECT * 
					FROM #PreviewSqlData
					ORDER BY Filter_Type, Value
				
					TRUNCATE TABLE #PreviewSqlData
				End
			End

		End -- </a>
	End -- </PepDB>

	-- how many rows did we add?
	--
	If @infoOnly = 0
	Begin	
		SELECT @endingSize = COUNT(*) FROM T_Analysis_Description
		Set @entriesAdded = @endingSize - @startingSize
	End

	Set @message = 'ImportNewAnalyses - MSMS: ' + convert(varchar(32), @entriesAdded)

	If @infoOnly = 0 and @entriesAdded > 0
		execute PostLogEntry 'Normal', @message, 'ImportNewMSMSAnalyses'

Done:
	return @myError


GO
GRANT EXECUTE ON [dbo].[ImportNewMSMSAnalyses] TO [DMS_SP_User]
GO
