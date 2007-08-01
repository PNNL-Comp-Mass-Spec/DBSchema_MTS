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

	declare @result int
	set @result = 0

	declare @startingSize int
	declare @endingSize int

	declare @SCampaign varchar(255)
	declare @SAddnl varchar(2000)
	declare @SCampaignAndAddnl varchar(2000)
	
	declare @S varchar(8000)
	declare @JobInfoTable varchar(256)
	declare @DatasetInfoTable varchar(256)

	declare @filterValueLookupTableName varchar(256)
	set @filterValueLookupTableName = ''
	
	declare @filterMatchCount int

	declare @UsingJobListOverride tinyint
	set @UsingJobListOverride =0
	
	declare @JobsByDualKeyFilters int
	
	declare @MatchCount int
	declare @expListCount int
	declare @expListCountExcluded int
	
	declare @datasetListCount int
	declare @datasetListCountExcluded int

	declare @Lf char(1)
	Set @Lf = char(10)

	declare @CrLf char(2)
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
		if @myRowCount < 1 OR @campaign = ''
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

		-- Define the table where we will look up jobs from when calling ParseFilterListDualKey and ParseFilterList
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
			set @myError = 40006
			goto Done
		end
		--
		if @myRowCount = 0 OR IsDate(@DateText) = 0
			Set @DateText = ''

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
			

		-- Combine the Campaign fitler with the additional filters
		set @SCampaignAndAddnl = @SCampaign + ' AND' + @SAddnl
		

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
			SELECT Convert(int, Value) FROM #TmpFilterList
			--
			select @myError = @@error, @myRowCount = @@rowcount
			
			Set @JobsByDualKeyFilters = @JobsByDualKeyFilters + @myRowCount

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
			set @myError = 40002
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
			set @myError = 40003
			goto Done
		end
		Else
		begin
			INSERT INTO #TmpExperimentsExcluded (Experiment)
			SELECT Value FROM #TmpFilterList
			--
			select @myError = @@error, @expListCountExcluded = @@rowcount

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
			set @myError = 40004
			goto Done
		end
		Else
		begin
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
			set @myError = 40005
			goto Done
		end
		Else
		begin
			INSERT INTO #TmpDatasetsExcluded (Dataset)
			SELECT Value FROM #TmpFilterList
			--
			select @myError = @@error, @datasetListCountExcluded = @@rowcount

			If @PreviewSql <> 0
				INSERT INTO #PreviewSqlData (Filter_Type, Value)
				SELECT 'Dataset Exclusion', Dataset 
				FROM #TmpDatasetsExcluded
		End


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
			set @S = @S + '	Job, Dataset, Dataset_ID, Dataset_Created_DMS,'
			set @S = @S + ' Experiment, Campaign, Organism,'
			set @S = @S + '	Instrument_Class, Instrument, Analysis_Tool,'
			set @S = @S + '	Parameter_File_Name, Settings_File_Name,'
			set @S = @S + ' Organism_DB_Name, Protein_Collection_List, Protein_Options_List,'
			set @S = @S + '	Vol_Client, Vol_Server, Storage_Path, Dataset_Folder, Results_Folder,'
			set @S = @S + '	Completed, ResultType, Separation_Sys_Type,'
			set @S = @S + ' PreDigest_Internal_Std, PostDigest_Internal_Std, Dataset_Internal_Std,'
			set @S = @S + ' Labelling, Created, Auto_Addition, State'
			set @S = @S + ') ' + @Lf
		End
		set @S = @S + 'SELECT DISTINCT * '
		set @S = @S + 'FROM (' + @Lf
		set @S = @S +   'SELECT '
		set @S = @S +   ' Job, Dataset, DatasetID, DS_Created,' + @Lf
		set @S = @S +   ' Experiment, Campaign, Organism,' + @Lf
		set @S = @S +   ' InstrumentClass, InstrumentName, AnalysisTool,' + @Lf
		set @S = @S +   ' ParameterFileName, SettingsFileName,' + @Lf
		set @S = @S +   ' OrganismDBName, ProteinCollectionList, ProteinOptions,' + @Lf
		set @S = @S +   ' StoragePathClient, StoragePathServer, '''' AS StoragePath, DatasetFolder, ResultsFolder,' + @Lf
		set @S = @S +   ' Completed, ResultType, SeparationSysType,' + @Lf
		set @S = @S +   ' [PreDigest Int Std], [PostDigest Int Std], [Dataset Int Std],' + @Lf
		set @S = @S +   ' Labelling, GetDate() As Created, 1 As Auto_Addition, 1 As StateNew ' + @Lf
		set @S = @S +   'FROM ' + @JobInfoTable + ' DAJI ' + @Lf

		If @UsingJobListOverride = 1
		Begin
			set @S = @S + ' INNER JOIN #T_Tmp_JobListOverride JobListQ ON DAJI.Job = JobListQ.JobOverride' + @Lf
		End
		Else			
		Begin
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
			set @S = @S + ')'
			
			-- Now add jobs found using the alternate job selection method
			If @JobsByDualKeyFilters > 0
			Begin
				set @S = @S + ' OR (Job IN (SELECT Job FROM #TmpJobsByDualKeyFilters)) ' + @Lf
			End
		End
		
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
		begin	
			SELECT @endingSize = COUNT(*) FROM T_FTICR_Analysis_Description
			set @entriesAdded = @endingSize - @startingSize
			
			if @entriesAdded > 0
			Begin
				---------------------------------------------------
				-- Also update the Dataset stat columns using V_DMS_Dataset_Import_Ex
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
				Set @S = @S +            @DatasetInfoTable + ' AS R ON '
				Set @S = @S +          ' L.Dataset_ID = R.ID AND ('
				Set @S = @S +          ' L.Dataset_Created_DMS <> R.Created OR '
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
		end
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
GRANT EXECUTE ON [dbo].[ImportNewMSAnalyses] TO [DMS_SP_User]
GO