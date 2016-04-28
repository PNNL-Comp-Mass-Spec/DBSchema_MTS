/****** Object:  StoredProcedure [dbo].[ImportNewMSAnalyses] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure ImportNewMSAnalyses
/****************************************************
**
**	Desc: Imports LC-MS job entries from the analysis job table
**        in the linked DMS database and inserts them
**        into the local MS analysis description table
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**	Auth:	grk
**	Date:	12/04/2001
**			09/16/2003 grk - Added table lookup for allowed instruments
**			11/05/2003 grk - Modified dynamic SQL to use new import criteria tables
**			03/05/2004 mem - Added ability to specify job numbers to force for import, regardless of other criteria
**			09/20/2004 mem - Modified to use T_Process_Config and additional import criteria
**			09/22/2004 mem - Added ability to handle Experiment filter parameters in T_Process_Config that contain a wildcard character (percent sign)
**			09/24/2004 mem - Added ability to handle Experiment_Exclusion filter parameters in T_Process_Config
**			10/01/2004 mem - Added ability to handle Dataset and Dataset_Exclusion filter parameters in T_Process_Config
**			03/07/2005 mem - Now checking for no matching Experiments if an experiment inclusion filter is defined; also checking for no matching datasets if a dataset inclusion filter is defined
**			04/06/2005 mem - Added ability to handle Campaign_and_Experiment filter parameter in T_Process_Config
**			07/07/2005 mem - Now populating column Instrument
**			07/08/2005 mem - Now populating column Internal_Standard
**			07/18/2005 mem - Now populating column Labelling
**			11/13/2005 mem - Now populating columns Dataset_Acq_Time_Start, Dataset_Acq_Time_End, and Dataset_Scan_Count
**			11/30/2005 mem - Added parameter @PreviewSql
**			12/15/2005 mem - Now populating T_FTICR_Analysis_Description with PreDigest_Internal_Std, PostDigest_Internal_Std, and Dataset_Internal_Std (previously named Internal_Standard)
**			02/23/2006 mem - Updated this SP to post a message to the log if new entries are added rather than having the calling procedure do so
**			02/24/2006 mem - Updated to only consider the jobs in @JobListOverride if defined; previously, would still add jobs passing the default filters even if @JobListOverride contained one or more jobs
**			03/02/2006 mem - Fixed bug that was posting a log entry when @infoOnly = 1 rather than when @infoOnly = 0
**			06/04/2006 mem - Now populating T_Analysis_Description with Protein_Collection_List and Protein_Options_List
**			08/01/2006 mem - Increased size of @JobListOverride and switched to use udfParseDelimitedList to parse the list
**			11/29/2006 mem - Now adding a line feed character in key places to aid readability when using @PreviewSql = 1
**			12/01/2006 mem - Now using udfParseDelimitedIntegerList to parse @JobListOverride
**			03/14/2007 mem - Changed @JobListOverride parameter from varchar(8000) to varchar(max)
**			03/17/2007 mem - Now obtaining StoragePathClient and StoragePathServer from V_DMS_Analysis_Job_Import_Ex
**			05/12/2007 mem - Added parameter @UseCachedDMSDataTables (Ticket:422)
**						   - Switched to Try/Catch error handling
**			08/14/2008 mem - Renamed Organism field to Experiment_Organism in T_FTICR_Analysis_Description
**			08/07/2009 mem - Now sending @PreviewSql to ParseFilterListDualKey
**			07/09/2010 mem - Now excluding Peptide_Hit jobs when @JobListOverride is used (to avoid adding MS/MS search jobs to T_FTICR_Analysis_Description)
**						   - Now showing the dataset name, tool name, and result type when @InfoOnly = 1 
**			07/13/2010 mem - Now validating the dataset acquisition length against the ranges defined in T_Process_Config
**						   - Now populating DS_Acq_Length in T_FTICR_Analysis_Description
**			05/04/2011 mem - Now skipping several filter lookup steps when @JobListOverride has jobs listed
**			03/28/2012 mem - Now using parameters MS_Job_Minimum and MS_Job_Maximum from T_Process_Config (if defined); ignored if @JobListOverride is used
**			10/10/2013 mem - Now populating MyEMSLState
**			11/08/2013 mem - Now passing @previewSql to ParseFilterList
**			04/27/2016 mem - Added support for DataPkg_Import_MS
**    
*****************************************************/
(
	@entriesAdded int = 0 output,
	@message varchar(512) = '' output,
	@infoOnly int = 0,
	@JobListOverride varchar(max) = '',
	@PreviewSql tinyint = 0,					-- Set to 1 to display the table population Sql statements
	@UseCachedDMSDataTables tinyint = 1			-- Set to 1 to use tables T_DMS_Analysis_Job_Info_Cached and T_DMS_Dataset_Info_Cached in MT_Main rather than the views that connect to DMS; if any jobs listed in @JobListOverride are not found in T_DMS_Analysis_Job_Info_Cached, then @UseCachedDMSDataTables will automatically be set to 0 
)
As
	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @result int = 0

	declare @startingSize int
	declare @endingSize int

	declare @SCampaign varchar(255)
	declare @SAddnl varchar(2000)
	declare @SCampaignAndAddnl varchar(2000)
	
	declare @S varchar(8000)
	declare @JobInfoTable varchar(256)
	declare @DatasetInfoTable varchar(256)

	declare @filterValueLookupTableName varchar(256) = ''
	
	declare @filterMatchCount int

	declare @UsingJobListOverrideOrDataPkg tinyint = 0
	declare @DataPkgFilterDefined tinyint = 0
	
	declare @JobsByDualKeyFilters int
	
	declare @MatchCount int
	declare @expListCount int
	declare @expListCountExcluded int
	
	declare @datasetListCount int
	declare @datasetListCountExcluded int

	declare @Lf char(1) = char(10)

	declare @CrLf char(2) = char(10) + char(13)

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
		-- Check whether we will be importing jobs using a data package filter
		---------------------------------------------------
		--
		If Exists (SELECT Value FROM T_Process_Config WHERE [Name] = 'DataPkg_Import_MS' AND IsNull(Value, '') <> '')
		Begin
			Set @DataPkgFilterDefined = 1
		End
		
		---------------------------------------------------
		-- Make sure at least one campaign is defined for this mass tag database
		---------------------------------------------------
		--
		declare @campaign varchar(64)
		set @campaign = ''
		--
		SELECT TOP 1 @campaign = Value
		FROM T_Process_Config
		WHERE [Name] IN ('Campaign', 'Campaign_and_Experiment') AND Len(Value) > 0
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if (@myRowCount < 1 OR @campaign = '') And @DataPkgFilterDefined = 0 And Len(@JobListOverride) = 0
		begin
			set @myError = 40001
			goto Done
		end

		---------------------------------------------------
		-- Create several temporary tables
		---------------------------------------------------
		--
		Set @CurrentLocation = 'Create temporary tables'
		--
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
		Begin
			CREATE TABLE #PreviewSqlData (
				Filter_Type varchar(128), 
				Value varchar(128) NULL
			)
		End
		
		---------------------------------------------------
		-- Create a temporary table to hold jobs from @JobListOverride plus any DataPkg_Import_MSMS jobs
		---------------------------------------------------
		--
		CREATE TABLE #T_Tmp_JobListOverride (
			JobOverride int
		)
		
		If Len(@JobListOverride) > 0
		Begin -- <a1>
			
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

			Set @UsingJobListOverrideOrDataPkg = 1
		End -- </a1>
		
		If Len(@JobListOverride) = 0 And @DataPkgFilterDefined > 0
		Begin -- <a2>
			---------------------------------------------------
			-- Find jobs that are associated with the data package(s) defined in T_Process_Config
			-- yet are not in T_FTICR_Analysis_Description
			---------------------------------------------------					
			
			-- First lookup the Data Package IDs
			--
			DECLARE @DataPackageList TABLE (Data_Package_ID int NOT NULL)
			
			INSERT INTO @DataPackageList (Data_Package_ID)
			SELECT Convert(int, Value)
			FROM T_Process_Config
			WHERE [Name] = 'DataPkg_Import_MS' And IsNumeric(Value) > 0
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount


			If @infoOnly <> 0
			Begin				
				SELECT Data_Package_ID, 'DataPkg_Import_MS filter' AS Comment
				FROM @DataPackageList
			End

			-- Now find jobs associated with those Data Packages
			--
			INSERT INTO #T_Tmp_JobListOverride (JobOverride)
			SELECT SrcJobs.Job
			FROM MT_Main.dbo.T_DMS_Data_Package_Jobs_Cached SrcJobs
			     INNER JOIN @DataPackageList AS DataPackages
			       ON SrcJobs.Data_Package_ID = DataPackages.Data_Package_ID
			     LEFT OUTER JOIN T_FTICR_Analysis_Description TAD
			       ON SrcJobs.Job = TAD.Job
			WHERE TAD.Job IS NULL
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			Set @UsingJobListOverrideOrDataPkg = 1
			
		End -- </a2>
		
		If @UsingJobListOverrideOrDataPkg > 0 AND @UseCachedDMSDataTables = 1
		Begin -- <a3>
			-- Make sure all of the jobs defined in #T_Tmp_JobListOverride are present in T_DMS_Analysis_Job_Info_Cached
			-- If not, we'll change @UseCachedDMSDataTables to 0
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
		End -- </a3>

		---------------------------------------------------
		-- Define the job and dataset info table names
		---------------------------------------------------
		--
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

		If @UsingJobListOverrideOrDataPkg <> 0 And @InfoOnly <> 0
		Begin
			set @S = ''
			set @S = @S + ' SELECT JobListQ.JobOverride, DAJI.Dataset, DAJI.AnalysisTool, DAJI.ResultType, DAJI.Completed,' + @Lf
			set @S = @S + '  CASE WHEN ResultType Like ''%Peptide_Hit'' THEN ''Job will not import because Peptide_Hit'''  + @Lf
			set @S = @S + '       WHEN ResultType    = ''SIC''          THEN ''Job will not import because SIC'''  + @Lf
			set @S = @S + '       ELSE Cast('''' as Varchar(128)) END AS Comment'  + @Lf
			set @S = @S + ' FROM #T_Tmp_JobListOverride JobListQ LEFT OUTER JOIN ' + @Lf
			set @S = @S + '      ' + @JobInfoTable + ' DAJI ON DAJI.Job = JobListQ.JobOverride' + @Lf
			set @S = @S + ' ORDER BY JobListQ.JobOverride' + @Lf
			
			If @PreviewSql <> 0
			Begin
				Print '-- SQL used to show Datasets and Tool Names for jobs in #T_Tmp_JobListOverride'
				Print @S
			End
				
			Exec (@S)
		End


		-- Define the table where we will look up jobs from when calling ParseFilterListDualKey and ParseFilterList
		set @filterValueLookupTableName = @JobInfoTable
		
		Set @CurrentLocation = 'Determine import options'
		
		If @UsingJobListOverrideOrDataPkg = 0
		Begin -- <a4>
		
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
				set @myError = 40006
				goto Done
			end
			--
			if @myRowCount = 0 OR IsDate(@DateText) = 0
				Set @DateText = ''


			---------------------------------------------------
			-- Look for MS_Job_Minimum and MS_Job_Maximum in T_Process_Config
			-- (ignored if @JobListOverride is defined)
			---------------------------------------------------
			--
			declare @JobMinimum int = 0
			declare @JobMaximum int = 0
			declare @ErrorOccurred tinyint = 0
			
			If @UsingJobListOverrideOrDataPkg = 0
			Begin
				exec GetProcessConfigValueInt 'MS_Job_Minimum', @DefaultValue=0, @ConfigValue=@JobMinimum output, @LogErrors=0, @ErrorOccurred=@ErrorOccurred output
			
				If @ErrorOccurred > 0
				Begin
					Set @message = 'Entry for MS_Job_Minimum in T_Process_Config is not numeric; unable to apply job number filter'
					Exec PostLogEntry 'Error', @message, 'ImportNewMSAnalyses'
					Goto Done
				End
			
				exec GetProcessConfigValueInt 'MS_Job_Maximum', @DefaultValue=0, @ConfigValue=@JobMaximum output, @LogErrors=0, @ErrorOccurred=@ErrorOccurred output
			
				If @ErrorOccurred > 0
				Begin
					Set @message = 'Entry for MS_Job_Maximum in T_Process_Config is not numeric; unable to apply job number filter'
					Exec PostLogEntry 'Error', @message, 'ImportNewMSAnalyses'
					Goto Done
				End	
			End

			---------------------------------------------------
			-- Lookup the dataset acquisition length range defined in T_Process_Config
			-- If no entry is present, then @AcqLengthFilterEnabled will be 0
			---------------------------------------------------
				
			Declare @AcqLengthFilterEnabled tinyint
			Declare @AcqLengthMinimum real
			Declare @AcqLengthMaximum real
			
			Set @AcqLengthFilterEnabled = 0
			
			Exec @result = GetAllowedDatasetAcqLength @AcqLengthMinimum OUTPUT, 
													@AcqLengthMaximum OUTPUT,
													@AcqLengthFilterEnabled OUTPUT,
													@LogErrors=1
			
			If @result <> 0
			Begin
				Set @message = 'GetAllowedDatasetAcqLength returned a non-zero value (' + Convert(varchar(12), @result) + '); aborting import'
				Goto Done
			End


			---------------------------------------------------
			-- See if any experiment or dataset inclusion/exclusion filters are defined in T_Process_Config
			-- Populate the various temporary tables as needed
			---------------------------------------------------
			
			-- First, construct the Campaign Sql and the InstrumentClass, SeparationSysType, and ResultType Sql

			set @SCampaign = ''
			set @SCampaign = @SCampaign + ' Campaign IN '
			set @SCampaign = @SCampaign + '( '
			set @SCampaign = @SCampaign + ' SELECT Value '
			set @SCampaign = @SCampaign + ' FROM T_Process_Config '
			set @SCampaign = @SCampaign + ' WHERE [Name] = ''Campaign'' AND Len(Value) > 0'
			set @SCampaign = @SCampaign + ')' + @Lf
			
			set @SAddnl = ''
			set @SAddnl = @SAddnl + ' InstrumentClass IN '
			set @SAddnl = @SAddnl + '( '
			set @SAddnl = @SAddnl + ' SELECT Value '
			set @SAddnl = @SAddnl + ' FROM T_Process_Config '
			set @SAddnl = @SAddnl + ' WHERE [Name] = ''MS_Instrument_Class'' AND Len(Value) > 0'
			set @SAddnl = @SAddnl + ') ' + @Lf
			set @SAddnl = @SAddnl + ' AND SeparationSysType IN '
			set @SAddnl = @SAddnl + '( '
			set @SAddnl = @SAddnl + ' SELECT Value '
			set @SAddnl = @SAddnl + ' FROM T_Process_Config '
			set @SAddnl = @SAddnl + ' WHERE [Name] = ''Separation_Type'' AND Len(Value) > 0'
			set @SAddnl = @SAddnl + ') ' + @Lf
			set @SAddnl = @SAddnl + ' AND ResultType IN '
			set @SAddnl = @SAddnl + '( '
			set @SAddnl = @SAddnl + ' SELECT Value '
			set @SAddnl = @SAddnl + ' FROM T_Process_Config '
			set @SAddnl = @SAddnl + ' WHERE [Name] = ''MS_Result_Type'' AND Len(Value) > 0'
			set @SAddnl = @SAddnl + ') ' + @Lf

			if Len(@DateText) > 0
				set @SAddnl = @SAddnl + ' AND DS_Created >= ''' + @DateText + ''' ' + @Lf
				

			-- Combine the Campaign filter with the additional filters
			set @SCampaignAndAddnl = @SCampaign + ' AND' + @SAddnl
			

			---------------------------------------------------
			-- Populate #TmpJobsByDualKeyFilters using jobs that match
			-- experiments specified by Campaign_and_Experiment entries
			-- in T_Process_Config
			---------------------------------------------------

			set @JobsByDualKeyFilters = 0
			
			set @filterMatchCount = 0
			Exec @myError = ParseFilterListDualKey 'Campaign_and_Experiment', @filterValueLookupTableName, 'Campaign', 'Experiment', 'Job', @SAddnl, @filterMatchCount OUTPUT, @PreviewSql=@PreviewSql
			--
			if @myError <> 0
			begin
				set @message = 'Error looking up matching jobs by Campaign and Experiment'
				set @myError = 40002
				goto Done
			end
			Else
			begin -- <b1>
				INSERT INTO #TmpJobsByDualKeyFilters (Job)
				SELECT Convert(int, Value) 
				FROM #TmpFilterList
				--
				select @myError = @@error, @myRowCount = @@rowcount
				
				Set @JobsByDualKeyFilters = @JobsByDualKeyFilters + @myRowCount

				If @PreviewSql <> 0
					INSERT INTO #PreviewSqlData (Filter_Type, Value)
					SELECT 'Jobs matching Campaign/Experiment dual filter', Convert(varchar(18), Job)
					FROM #TmpJobsByDualKeyFilters
								
				If @JobMinimum > 0
					DELETE FROM #TmpJobsByDualKeyFilters
					WHERE Job < @JobMinimum

				If @JobMaximum > 0
					DELETE FROM #TmpJobsByDualKeyFilters
					WHERE Job > @JobMaximum
			End -- </b1>
			

			---------------------------------------------------
			-- See if any experiments are defined in T_Process_Config
			-- Populate #TmpExperiments with list of experiment names
			-- If any contain a percent sign, then use that as a matching
			--  parameter to populate #TmpExperiments
			---------------------------------------------------
			--

			set @expListCount = 0
			set @filterMatchCount = 0
			Exec @myError = ParseFilterList 'Experiment', @filterValueLookupTableName, 'Experiment', @SCampaignAndAddnl, @filterMatchCount OUTPUT, @previewSql=@previewSql
			--
			if @myError <> 0
			begin
				set @message = 'Error looking up experiment inclusion filter names'
				set @myError = 40002
				goto Done
			end
			Else
			begin -- <b2>
				INSERT INTO #TmpExperiments (Experiment)
				SELECT Value FROM #TmpFilterList
				--
				select @myError = @@error, @expListCount = @@rowcount
				
				If @expListCount = 0 And @filterMatchCount > 0
				Begin
					-- The user defined an experiment inclusion filter containing a %, but none matched
					-- Add a bogus entry to #TmpExperiments to guarantee that no jobs will match
					INSERT INTO #TmpExperiments (Experiment)
					VALUES ('FakeExperiment_' + Convert(varchar(64), NewId()))
					--
					select @myError = @@error, @expListCount = @@rowcount			
				End

				If @PreviewSql <> 0
					INSERT INTO #PreviewSqlData (Filter_Type, Value)
					SELECT 'Experiment Inclusion', Experiment 
					FROM #TmpExperiments
			End -- </b2>


			---------------------------------------------------
			-- See if any excluded experiments are defined in T_Process_Config
			-- Populate #TmpExperimentsExcluded with list of experiment names
			---------------------------------------------------
			--
			set @expListCountExcluded = 0
			Exec @myError = ParseFilterList 'Experiment_Exclusion', @filterValueLookupTableName, 'Experiment', @SCampaignAndAddnl, @previewSql=@previewSql
			--
			if @myError <> 0
			begin
				set @message = 'Error looking up experiment exclusion filter names'
				set @myError = 40003
				goto Done
			end
			Else
			begin -- <b3>
				INSERT INTO #TmpExperimentsExcluded (Experiment)
				SELECT Value FROM #TmpFilterList
				--
				select @myError = @@error, @expListCountExcluded = @@rowcount

				If @PreviewSql <> 0
					INSERT INTO #PreviewSqlData (Filter_Type, Value)
					SELECT 'Experiment Exclusion', Experiment 
					FROM #TmpExperimentsExcluded
			End -- </b3>


			---------------------------------------------------
			-- See if any datasets are defined in T_Process_Config
			-- Populate #TmpDatasets with list of dataset names
			---------------------------------------------------
			--
			set @datasetListCount = 0
			set @filterMatchCount = 0
			Exec @myError = ParseFilterList 'Dataset', @filterValueLookupTableName, 'Dataset', @SCampaignAndAddnl, @filterMatchCount OUTPUT, @previewSql=@previewSql
			--
			if @myError <> 0
			begin
				set @message = 'Error looking up dataset inclusion filter names'
				set @myError = 40004
				goto Done
			end
			Else
			begin -- <b4>
				INSERT INTO #TmpDatasets (Dataset)
				SELECT Value FROM #TmpFilterList
				--
				select @myError = @@error, @datasetListCount = @@rowcount

				If @datasetListCount = 0 And @filterMatchCount > 0
				Begin
					-- The user defined a dataset inclusion filter containing a %, but none matched
					-- Add a bogus entry to #TmpDatasets to guarantee that no jobs will match
					INSERT INTO #TmpDatasets (Dataset)
					VALUES ('FakeDataset_' + Convert(varchar(64), NewId()))
					--
					select @myError = @@error, @datasetListCount = @@rowcount			
				End

				If @PreviewSql <> 0
					INSERT INTO #PreviewSqlData (Filter_Type, Value)
					SELECT 'Dataset Inclusion', Dataset 
					FROM #TmpDatasets
			End -- </b4>


			---------------------------------------------------
			-- See if any excluded datasets are defined in T_Process_Config
			-- Populate #TmpDatasetsExcluded with list of dataset names
			---------------------------------------------------
			--
			set @datasetListCountExcluded = 0
			Exec @myError = ParseFilterList 'Dataset_Exclusion', @filterValueLookupTableName, 'Dataset', @SCampaignAndAddnl, @previewSql=@previewSql
			--
			if @myError <> 0
			begin
				set @message = 'Error looking up dataset exclusion filter names'
				set @myError = 40005
				goto Done
			end
			Else
			begin -- <b5>
				INSERT INTO #TmpDatasetsExcluded (Dataset)
				SELECT Value FROM #TmpFilterList
				--
				select @myError = @@error, @datasetListCountExcluded = @@rowcount

				If @PreviewSql <> 0
					INSERT INTO #PreviewSqlData (Filter_Type, Value)
					SELECT 'Dataset Exclusion', Dataset 
					FROM #TmpDatasetsExcluded
			End -- </b5>

		End -- </a4>
	
		---------------------------------------------------
		-- Import analyses for valid MS instrument classes
		---------------------------------------------------
		--
		Set @CurrentLocation = 'Import job candidates'
		
		-- get entries from the analysis job table 
		-- in the linked DMS database that pass the
		-- given criteria and have not already been imported
		--

		-- remember size of MS analysis description table
		--
		SELECT @startingSize = COUNT(*) FROM T_FTICR_Analysis_Description

		set @S = ''
		
		if @infoOnly = 0
		Begin
			set @S = @S + 'INSERT INTO T_FTICR_Analysis_Description ('
			set @S = @S + '	Job, Dataset, Dataset_ID, Dataset_Created_DMS, Dataset_Acq_Length,'
			set @S = @S + ' Experiment, Campaign, Experiment_Organism,'
			set @S = @S + '	Instrument_Class, Instrument, Analysis_Tool,'
			set @S = @S + '	Parameter_File_Name, Settings_File_Name,'
			set @S = @S + ' Organism_DB_Name, Protein_Collection_List, Protein_Options_List,'
			set @S = @S + '	Vol_Client, Vol_Server, Storage_Path, Dataset_Folder, Results_Folder, MyEMSLState,'
			set @S = @S + '	Completed, ResultType, Separation_Sys_Type,'
			set @S = @S + ' PreDigest_Internal_Std, PostDigest_Internal_Std, Dataset_Internal_Std,'
			set @S = @S + ' Labelling, Created, Auto_Addition, State'
			set @S = @S + ') ' + @Lf
		End
		set @S = @S + 'SELECT DISTINCT * '
		set @S = @S + 'FROM (' + @Lf
		set @S = @S +   'SELECT '
		set @S = @S +   ' Job, Dataset, DatasetID, DS_Created, IsNull(DS_Acq_Length, 0) AS Dataset_Acq_Length,' + @Lf
		set @S = @S +   ' Experiment, Campaign, Organism,' + @Lf
		set @S = @S +   ' InstrumentClass, InstrumentName, AnalysisTool,' + @Lf
		set @S = @S +   ' ParameterFileName, SettingsFileName,' + @Lf
		set @S = @S +   ' OrganismDBName, ProteinCollectionList, ProteinOptions,' + @Lf
		set @S = @S +   ' StoragePathClient, StoragePathServer, '''' AS StoragePath, DatasetFolder, ResultsFolder, MyEMSLState,' + @Lf
		set @S = @S +   ' Completed, ResultType, SeparationSysType,' + @Lf
		set @S = @S +   ' [PreDigest Int Std], [PostDigest Int Std], [Dataset Int Std],' + @Lf
		set @S = @S +   ' Labelling, GetDate() As Created, 1 As Auto_Addition, 1 As StateNew ' + @Lf
		set @S = @S +   'FROM ' + @JobInfoTable + ' DAJI ' + @Lf

		If @UsingJobListOverrideOrDataPkg = 1
		Begin
			set @S = @S + ' INNER JOIN #T_Tmp_JobListOverride JobListQ ON DAJI.Job = JobListQ.JobOverride' + @Lf
			set @S = @S + ' WHERE NOT (ResultType Like ''%Peptide_Hit'' OR ResultType = ''SIC'')'
		End
		Else			
		Begin -- <a5>
						
			set @S = @S +   ' WHERE (' + @Lf
			set @S = @S + @SCampaignAndAddnl
			
			if @expListCount > 0
			begin
				set @S = @S + 'AND Experiment IN '
				set @S = @S + '( '
				set @S = @S + '	SELECT Experiment FROM #TmpExperiments '
				set @S = @S + ') ' + @Lf
			end
			
			if @expListCountExcluded > 0
			begin
				set @S = @S + 'AND NOT Experiment IN '
				set @S = @S + '( '
				set @S = @S + '	SELECT Experiment FROM #TmpExperimentsExcluded '
				set @S = @S + ') ' + @Lf
			End

			if @datasetListCount > 0
			begin
				set @S = @S + 'AND Dataset IN '
				set @S = @S + '( '
				set @S = @S + '	SELECT Dataset FROM #TmpDatasets '
				set @S = @S + ') ' + @Lf
			end

			if @datasetListCountExcluded > 0
			begin
				set @S = @S + 'AND NOT Dataset IN '
				set @S = @S + '( '
				set @S = @S + '	SELECT Dataset FROM #TmpDatasetsExcluded '
				set @S = @S + ') ' + @Lf
			end

			if @AcqLengthFilterEnabled > 0
			begin
				Set @S = @S + ' AND IsNull(DS_Acq_Length, 0) BETWEEN '
				Set @S = @S +     Convert(varchar(12), @AcqLengthMinimum) + ' AND '
				Set @S = @S +     Convert(varchar(12), @AcqLengthMaximum) + @Lf
			end
	
			If @JobMinimum > 0
			begin
				Set @S = @S + ' AND Job >= ' + Convert(varchar(12), @JobMinimum) + @Lf
			end
			
			If @JobMaximum > 0
			begin
				Set @S = @S + ' AND Job <= ' + Convert(varchar(12), @JobMaximum) + @Lf
			end
			
			set @S = @S + ')'
			
			-- Now add jobs found using the alternate job selection method
			If @JobsByDualKeyFilters > 0
			Begin
				set @S = @S + ' OR (Job IN (SELECT Job FROM #TmpJobsByDualKeyFilters)) ' + @Lf
			End
		End -- </a5>
		
		set @S = @S + ') As LookupQ' + @Lf
		set @S = @S + ' WHERE Job NOT IN (SELECT Job FROM T_FTICR_Analysis_Description)' + @Lf
		set @S = @S + ' ORDER BY Job'

		If @PreviewSql <> 0
		Begin
			Print '-- Sql used to import new MS analyses'
			Print @S + @CrLf
		End
		--			
		exec (@S)
		--
		select @myError = @result, @myRowcount = @@rowcount
		--
		if @myError  <> 0
		begin
			set @message = 'Error appending new jobs to T_FTICR_Analysis_Description'
			set @myError = 40007
			goto Done
		end

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

		-- how many rows did we add?
		--
		if @infoOnly = 0
		begin -- <a6>	
			SELECT @endingSize = COUNT(*) FROM T_FTICR_Analysis_Description
			set @entriesAdded = @endingSize - @startingSize
			
			if @entriesAdded > 0
			Begin
				---------------------------------------------------
				-- Also update the Dataset stat columns using V_DMS_Dataset_Import_Ex
				-- Note that Dataset_Acq_Length should have already been populated 
				--  using V_DMS_Analysis_Job_Import_Ex or T_DMS_Analysis_Job_Info_Cached in MT_Main
				---------------------------------------------------
				--
				Set @CurrentLocation = 'Update Dataset stat columns'
				
				Set @S = ''
				Set @S = @S + ' UPDATE T_FTICR_Analysis_Description'
				Set @S = @S + ' SET Dataset_Created_DMS = P.Created,'
				Set @S = @S +     ' Dataset_Acq_Time_Start = P.[Acquisition Start], '
				Set @S = @S +     ' Dataset_Acq_Time_End = P.[Acquisition End],'
				Set @S = @S +     ' Dataset_Scan_Count = P.[Scan Count]'
				Set @S = @S + ' FROM T_FTICR_Analysis_Description AS TAD INNER JOIN ('
				Set @S = @S +     ' SELECT L.Dataset_ID, R.Created, R.[Acquisition Start], R.[Acquisition End], R.[Scan Count]'
				Set @S = @S +     ' FROM T_FTICR_Analysis_Description AS L INNER JOIN '
				Set @S = @S +      @DatasetInfoTable + ' AS R ON '
				Set @S = @S +          ' L.Dataset_ID = R.ID AND ('
				Set @S = @S +    ' L.Dataset_Created_DMS <> R.Created OR '
				Set @S = @S +          ' IsNull(L.Dataset_Acq_Time_Start,0) <> IsNull(R.[Acquisition Start],0) OR'
				Set @S = @S +          ' IsNull(L.Dataset_Acq_Time_End,0) <> IsNull(R.[Acquisition End],0) OR'
				Set @S = @S +          ' IsNull(L.Dataset_Scan_Count,0) <> IsNull(R.[Scan Count],0))'
				Set @S = @S +     ' ) AS P on P.Dataset_ID = TAD.Dataset_ID'
				Set @S = @S + ' WHERE DateDiff(minute, TAD.Created, GetDate()) <= 2'
				--
				Exec (@S)
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				if @myError <> 0
				Begin
					Set @message = 'Error updating the Dataset stat columns in T_FTICR_Analysis_Description'
					Set @myError = 40008
					execute PostLogEntry 'Error', @message, 'ImportNewMSAnalyses'
				End
			End		
		end -- </a6>	
		else
		begin
			SELECT @entriesAdded = @myRowCount
		end 


		-- Post the log entry messages
		Set @CurrentLocation = 'Post the log entry messages'
		--		
		set @message = 'ImportNewAnalyses - MS: ' + convert(varchar(32), @entriesAdded)
		if @infoOnly = 0 and @entriesAdded > 0
			execute PostLogEntry 'Normal', @message, 'ImportNewMSAnalyses'
			
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'ImportNewMSAnalyses')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch
	
Done:
	return @myError


GO
GRANT EXECUTE ON [dbo].[ImportNewMSAnalyses] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ImportNewMSAnalyses] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ImportNewMSAnalyses] TO [MTS_DB_Lite] AS [dbo]
GO
