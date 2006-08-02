SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ImportNewFTICRAnalyses]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ImportNewFTICRAnalyses]
GO


CREATE Procedure dbo.ImportNewFTICRAnalyses
/****************************************************
**
**	Desc: Imports FTICR job entries from the analysis job table
**        in the linked DMS database and inserts them
**        into the local FTICR analysis description table
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**		Auth: grk
**		Date: 12/4/2001
**			  09/16/2003 grk - Added table lookup for allowed instruments
**			  11/05/2003 grk - Modified dynamic SQL to use new import criteria tables
**			  03/05/2004 mem - Added ability to specify job numbers to force for import, regardless of other criteria
**			  09/20/2004 mem - Modified to use T_Process_Config and additional import criteria
**			  09/22/2004 mem - Added ability to handle Experiment filter parameters in T_Process_Config that contain a wildcard character (percent sign)
**			  09/24/2004 mem - Added ability to handle Experiment_Exclusion filter parameters in T_Process_Config
**			  10/01/2004 mem - Added ability to handle Dataset and Dataset_Exclusion filter parameters in T_Process_Config
**			  03/07/2005 mem - Now checking for no matching Experiments if an experiment inclusion filter is defined; also checking for no matching datasets if a dataset inclusion filter is defined
**			  04/06/2005 mem - Added ability to handle Campaign_and_Experiment filter parameter in T_Process_Config
**			  07/07/2005 mem - Now populating column Instrument
**			  07/08/2005 mem - Now populating column Internal_Standard
**			  07/18/2005 mem - Now populating column Labelling
**			  11/13/2005 mem - Now populating columns Dataset_Acq_Time_Start, Dataset_Acq_Time_End, and Dataset_Scan_Count
**			  11/30/2005 mem - Added parameter @PreviewSql
**    
*****************************************************/
(
	@entriesAdded int = 0 output,
	@message varchar(512) = '' output,
	@infoOnly int = 0,
	@JobListOverride varchar(1024) = '',		-- Note: jobs passing the default filters will be added, even if values are provided for @JobListOverride.  To prevent this, define a fake Experiment filter in T_Process_Config
	@PreviewSql tinyint = 0						-- Set to 1 to display the table population Sql statements
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
	
	set @message = ''
	set @entriesAdded = 0

	declare @SCampaign varchar(255)
	declare @SAddnl varchar(2000)
	declare @SCampaignAndAddnl varchar(2000)
	
	declare @S varchar(8000)

	declare @filterValueLookupTableName varchar(256)
	declare @filterMatchCount int
	
	declare @JobsByDualKeyFilters int
	
	declare @expListCount int
	declare @expListCountExcluded int
	
	declare @datasetListCount int
	declare @datasetListCountExcluded int

	declare @CrLf char(2)
	Set @CrLf = char(10) + char(13)

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
	set @SCampaign = @SCampaign + ')'
	
	set @SAddnl = ''
	set @SAddnl = @SAddnl + ' InstrumentClass IN '
	set @SAddnl = @SAddnl + '( '
	set @SAddnl = @SAddnl + ' SELECT Value '
	set @SAddnl = @SAddnl + ' FROM T_Process_Config '
	set @SAddnl = @SAddnl + ' WHERE [Name] = ''MS_Instrument_Class'' AND Len(Value) > 0'
	set @SAddnl = @SAddnl + ') '
	set @SAddnl = @SAddnl + ' AND SeparationSysType IN '
	set @SAddnl = @SAddnl + '( '
	set @SAddnl = @SAddnl + ' SELECT Value '
	set @SAddnl = @SAddnl + ' FROM T_Process_Config '
	set @SAddnl = @SAddnl + ' WHERE [Name] = ''Separation_Type'' AND Len(Value) > 0'
	set @SAddnl = @SAddnl + ') '
	set @SAddnl = @SAddnl + ' AND ResultType IN '
	set @SAddnl = @SAddnl + '( '
	set @SAddnl = @SAddnl + ' SELECT Value '
	set @SAddnl = @SAddnl + ' FROM T_Process_Config '
	set @SAddnl = @SAddnl + ' WHERE [Name] = ''MS_Result_Type'' AND Len(Value) > 0'
	set @SAddnl = @SAddnl + ') '

	if Len(@DateText) > 0
		set @SAddnl = @SAddnl + ' AND DS_Created >= ''' + @DateText + ''' '
		

	-- Combine the Campaign fitler with the additional filters
	set @SCampaignAndAddnl = @SCampaign + ' AND ' + @SAddnl
	
	---------------------------------------------------
	-- Define the table where we will look up jobs from
	---------------------------------------------------
	set @filterValueLookupTableName = 'MT_Main.dbo.V_DMS_Analysis_Job_Import_Ex'

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
	-- Import analyses for valid FTICR instrument classes
	---------------------------------------------------
	--
	-- get entries from the analysis job table 
	-- in the linked DMS database that pass the
	-- given criteria and have not already been imported
	--

	-- remember size of FTICR analysis description table
	--
	SELECT @startingSize = COUNT(*) FROM T_FTICR_Analysis_Description

	set @S = ''
	
	if @infoOnly = 0
	Begin
		set @S = @S + 'INSERT INTO T_FTICR_Analysis_Description ('
		set @S = @S + '	Job, Dataset, Dataset_ID, Dataset_Created_DMS,'
		set @S = @S + ' Experiment, Campaign, Organism,'
		set @S = @S + '	Instrument_Class, Instrument, Analysis_Tool,'
		set @S = @S + '	Parameter_File_Name, Settings_File_Name, Organism_DB_Name,'
		set @S = @S + '	Vol_Client, Vol_Server, Storage_Path, Dataset_Folder, Results_Folder,'
		set @S = @S + '	Completed, ResultType, Separation_Sys_Type,'
		set @S = @S + '	Internal_Standard, Labelling,'
		set @S = @S + ' Created, Auto_Addition, State'
		set @S = @S + ') '
	End
	set @S = @S + 'SELECT DISTINCT * '
	set @S = @S + 'FROM ('
	set @S = @S +   'SELECT '
	set @S = @S +   ' Job, Dataset, DatasetID, DS_Created,'
	set @S = @S +   ' Experiment, Campaign, Organism,'
	set @S = @S +   ' InstrumentClass, InstrumentName, AnalysisTool,'
	set @S = @S +   ' ParameterFileName, SettingsFileName, OrganismDBName,'
	set @S = @S +   ' VolClient, VolServer, StoragePath, DatasetFolder, ResultsFolder,'
	set @S = @S +   ' Completed, ResultType, SeparationSysType,'
	set @S = @S +   ' [Internal Standard], Labelling, '
	set @S = @S +   ' GetDate() As Created, 1 As Auto_Addition, 1 As StateNew '
	set @S = @S +   'FROM MT_Main.dbo.V_DMS_Analysis_Job_Import_Ex '
	set @S = @S +   'WHERE ('
		set @S = @S +   @SCampaignAndAddnl
		
		if @expListCount > 0
		begin
			set @S = @S + 'AND Experiment IN '
			set @S = @S + '( '
			set @S = @S + '	SELECT Experiment FROM #TmpExperiments '
			set @S = @S + ') '
		end
		
		if @expListCountExcluded > 0
		begin
			set @S = @S + 'AND NOT Experiment IN '
			set @S = @S + '( '
			set @S = @S + '	SELECT Experiment FROM #TmpExperimentsExcluded '
			set @S = @S + ') '
		End

		if @datasetListCount > 0
		begin
			set @S = @S + 'AND Dataset IN '
			set @S = @S + '( '
			set @S = @S + '	SELECT Dataset FROM #TmpDatasets '
			set @S = @S + ') '
		end

		if @datasetListCountExcluded > 0
		begin
			set @S = @S + 'AND NOT Dataset IN '
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
	
	-- Now add jobs in @JobListOverride
	If Len(@JobListOverride) > 0
	Begin
		set @S = @S + ' OR (Job IN (' + @JobListOverride + '))'
	End

	set @S = @S + ') As LookupQ'
	set @S = @S + ' WHERE Job NOT IN '
	set @S = @S + ' (SELECT Job FROM T_FTICR_Analysis_Description)'
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
			UPDATE T_FTICR_Analysis_Description
			SET 
				Dataset_Created_DMS = P.Created,
				Dataset_Acq_Time_Start = P.[Acquisition Start], 
				Dataset_Acq_Time_End = P.[Acquisition End],
				Dataset_Scan_Count = P.[Scan Count]
			FROM T_FTICR_Analysis_Description AS TAD INNER JOIN (
				SELECT L.Dataset_ID, R.Created, R.[Acquisition Start], R.[Acquisition End], R.[Scan Count]
				FROM T_FTICR_Analysis_Description AS L INNER JOIN
					MT_Main.dbo.V_DMS_Dataset_Import_Ex AS R ON 
					L.Dataset_ID = R.ID AND (
						L.Dataset_Created_DMS <> R.Created OR 
						IsNull(L.Dataset_Acq_Time_Start,0) <> IsNull(R.[Acquisition Start],0) OR
						IsNull(L.Dataset_Acq_Time_End,0) <> IsNull(R.[Acquisition End],0) OR
						IsNull(L.Dataset_Scan_Count,0) <> IsNull(R.[Scan Count],0)
					) 
				) AS P on P.Dataset_ID = TAD.Dataset_ID
			WHERE DateDiff(minute, TAD.Created, GetDate()) <= 2
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0
			Begin
				Set @message = 'Error updating the Dataset stat columns in T_FTICR_Analysis_Description'
				Set @myError = 40008
				execute PostLogEntry 'Error', @message, 'ImportNewFTICRAnalyses'
			End
		End		
	end
	else
	begin
		SELECT @entriesAdded = @myRowCount
	end 
	
	set @message = 'ImportNewAnalyses - FTICR: ' + convert(varchar(32), @entriesAdded)

Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

