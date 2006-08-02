SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ImportNewLCQAnalyses]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ImportNewLCQAnalyses]
GO


CREATE Procedure dbo.ImportNewLCQAnalyses
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
**		Auth: grk
**		Date: 11/13/2001
**			  11/05/2003 grk - Modified dynamic SQL to use new import criteria tables
**			  09/20/2004 mem - Modified to use T_Process_Config and additional import criteria, to allow multiple Campaigns, and to allow multiple Peptide DBs
**			  09/22/2004 mem - Added ability to handle Experiment filter parameters in T_Process_Config that contain a wildcard character (percent sign)
**			  09/24/2004 mem - Added ability to handle Experiment_Exclusion filter parameters in T_Process_Config
**			  10/01/2004 mem - Added ability to handle Dataset and Dataset_Exclusion filter parameters
**			  11/27/2004 mem - Added column GANET_RSquared
**			  01/22/2005 mem - Added ScanTime_NET columns
**			  03/07/2005 mem - Now checking for no matching Experiments if an experiment inclusion filter is defined; also checking for no matching datasets if a dataset inclusion filter is defined
**			  04/06/2005 mem - Added ability to handle Campaign_and_Experiment filter parameter in T_Process_Config
**			  04/25/2005 mem - Added parameter @JobListOverride
**			  07/07/2005 mem - Now populating column Instrument
**			  07/08/2005 mem - Now populating column Internal_Standard
**			  07/18/2005 mem - Now populating column Labelling; also, switched location of Instrument from T_Datasets to T_Analysis_Description
**			  09/03/2005 mem - Now populating column Dataset_SIC_Job
**			  11/10/2005 mem - Now populating columns Dataset_Acq_Time_Start, Dataset_Acq_Time_End, and Dataset_Scan_Count
**			  11/30/2005 mem - Added brackets around @peptideDBName as needed to allow for DBs with dashes in the name
**							   Added parameter @PreviewSql
**			  12/01/2005 mem - Increased size of @peptideDBName from 64 to 128 characters
**    
*****************************************************/
(
	@entriesAdded int = 0 output,
	@message varchar(512) = '' output,
	@infoOnly int = 0,
	@JobListOverride varchar(4000) = '',		-- Note: jobs passing the default filters will be added, even if values are provided for @JobListOverride.  To prevent this, define a fake Experiment filter in T_Process_Config
	@PreviewSql tinyint = 0						-- Set to 1 to display the table population Sql statements
)
As
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @entriesAdded = 0
	set @message = ''

	declare @result int
	set @result = 0
		
	declare @startingSize int
	declare @endingSize int

	declare @peptideDBName varchar(128)
	declare @peptideDBID int
	declare @MissingPeptideDB tinyint
	
	set @peptideDBName = ''

	declare @SCampaign varchar(255)
	declare @SAddnl varchar(2000)
	declare @SCampaignAndAddnl varchar(2000)

	declare @S varchar(8000)
	declare @continue tinyint

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
	-- Construct the Campaign Sql and the Process_State, Organism_DB_Name, Parameter_File_Name, and Separation_Sys_Type Sql
	---------------------------------------------------
	set @SCampaign = ''
	set @SCampaign = @SCampaign + ' Campaign IN '
	set @SCampaign = @SCampaign + '( '
	set @SCampaign = @SCampaign + ' SELECT Value '
	set @SCampaign = @SCampaign + ' FROM T_Process_Config '
	set @SCampaign = @SCampaign + ' WHERE [Name] = ''Campaign'' AND Len(Value) > 0'
	set @SCampaign = @SCampaign + ')'
	
	set @SAddnl = ''
	set @SAddnl = @SAddnl + ' (Process_State = 70)'
	
	If @minGANETFit >= 0
		set @SAddnl = @SAddnl + ' AND (ISNULL(GANET_Fit, 0) >= ' + convert(varchar(12), @minGANETFit) + ')'  
	Else
		set @SAddnl = @SAddnl + ' AND (ISNULL(GANET_RSquared, 0) >= ' + convert(varchar(12), @minGANETRSquared) + ')'  
		
	set @SAddnl = @SAddnl + ' AND Organism_DB_Name IN '
	set @SAddnl = @SAddnl + '( '
	set @SAddnl = @SAddnl + '	SELECT Value '
	set @SAddnl = @SAddnl + '	FROM T_Process_Config '
	set @SAddnl = @SAddnl + '	WHERE [Name] = ''Organism_DB_File_Name'' AND Len(Value) > 0'
	set @SAddnl = @SAddnl + ') '
	set @SAddnl = @SAddnl + ' AND Parameter_File_Name IN '
	set @SAddnl = @SAddnl + '( '
	set @SAddnl = @SAddnl + '	SELECT Value '
	set @SAddnl = @SAddnl + '	FROM T_Process_Config '
	set @SAddnl = @SAddnl + '	WHERE [Name] = ''Parameter_File_Name'' AND Len(Value) > 0'
	set @SAddnl = @SAddnl + ') '
	set @SAddnl = @SAddnl + ' AND Separation_Sys_Type IN '
	set @SAddnl = @SAddnl + '( '
	set @SAddnl = @SAddnl + '	SELECT Value '
	set @SAddnl = @SAddnl + '	FROM T_Process_Config '
	set @SAddnl = @SAddnl + '	WHERE [Name] = ''Separation_Type'' AND Len(Value) > 0'
	set @SAddnl = @SAddnl + ') '
	

	-- Combine the Campaign filter with the additional filters
	set @SCampaignAndAddnl = @SCampaign + ' AND ' + @SAddnl	
	
	---------------------------------------------------
	-- Import analyses from peptide database(s)
	---------------------------------------------------
	--
	-- get entries from the analysis job table 
	-- in the linked peptide database(s)
	-- that meet selection criteria

	-- remember size of analysis description table
	--
	SELECT @startingSize = COUNT(*) FROM T_Analysis_Description
	

	-- Loop through peptide database(s) and insert analyses jobs
	--

	Set @continue = 1
	While @continue = 1
	Begin -- <a>
		SELECT TOP 1 @peptideDBName = PeptideDBName
		FROM #T_Peptide_Database_List
		ORDER BY PeptideDBName
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin -- <b>

			-- Lookup the PDB_ID value for @peptideDBName in MT_Main
			--
			Set @peptideDBID = 0
			SELECT @peptideDBID = PDB_ID
			FROM MT_Main..T_Peptide_Database_List
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
			-- Clear the filter tables
			---------------------------------------------------
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
				SELECT Convert(int, Value) FROM #TmpFilterList
				--
				select @myError = @@error, @JobsByDualKeyFilters = @@rowcount
				
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
				set @myError = 40007
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
				set @myError = 40008
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
				set @myError = 40009
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
			-- Construct the Sql to populate T_Analysis_Description
			---------------------------------------------------
			
			set @S = ''

			if @infoOnly = 0
			begin
				set @S = @S + 'INSERT INTO T_Analysis_Description ('
				set @S = @S + ' Job, Dataset, Dataset_ID,'
				set @S = @S + ' Dataset_Created_DMS, Dataset_Acq_Time_Start, Dataset_Acq_Time_End, Dataset_Scan_Count,'
				set @S = @S + ' Experiment, Campaign, PDB_ID,'
				set @S = @S + ' Dataset_SIC_Job, Organism, Instrument_Class, Instrument, Analysis_Tool,'
				set @S = @S + ' Parameter_File_Name, Settings_File_Name, Organism_DB_Name,'
				set @S = @S + ' Vol_Client, Vol_Server, Storage_Path, Dataset_Folder, Results_Folder,'
				set @S = @S + ' Completed, ResultType, Separation_Sys_Type,'
				set @S = @S + ' Internal_Standard, Enzyme_ID, Labelling,' 
				set @S = @S + ' Created, State, '
				set @S = @S + ' GANET_Fit, GANET_Slope, GANET_Intercept, GANET_RSquared,'
				set @S = @S + ' ScanTime_NET_Slope, ScanTime_NET_Intercept, ScanTime_NET_RSquared, ScanTime_NET_Fit'
				set @S = @S + ') '
			end
			--
			set @S = @S + 'SELECT DISTINCT * '
			set @S = @S + 'FROM ('
			set @S = @S + 'SELECT '
			set @S = @S + '	PT.Job, PT.Dataset, PT.Dataset_ID,'
			set @S = @S + ' DS.Created_DMS, DS.Acq_Time_Start, DS.Acq_Time_End, DS.Scan_Count,'
			set @S = @S + '	PT.Experiment, PT.Campaign, ' + Convert(varchar(11), @peptideDBID) + ' AS PDB_ID,'
			set @S = @S + ' DS.SIC_Job, PT.Organism, PT.Instrument_Class, PT.Instrument, PT.Analysis_Tool,'
			set @S = @S + '	PT.Parameter_File_Name,	PT.Settings_File_Name, PT.Organism_DB_Name,'
			set @S = @S + '	PT.Vol_Client, PT.Vol_Server, PT.Storage_Path, PT.Dataset_Folder, PT.Results_Folder,'
			set @S = @S + '	PT.Completed, PT.ResultType, PT.Separation_Sys_Type,'
			set @S = @S + ' PT.Internal_Standard, PT.Enzyme_ID, PT.Labelling,'
			set @S = @S + '	PT.Created, 1 AS StateNew,'
			set @S = @S + '	PT.GANET_Fit, PT.GANET_Slope, PT.GANET_Intercept, PT.GANET_RSquared,'
			set @S = @S + '	ScanTime_NET_Slope, ScanTime_NET_Intercept, ScanTime_NET_RSquared, ScanTime_NET_Fit '
			set @S = @S + 'FROM '
			set @S = @S +   '[' + @peptideDBName + '].dbo.T_Analysis_Description AS PT LEFT OUTER JOIN '
			set @S = @S +   '[' + @peptideDBName + '].dbo.T_Datasets AS DS ON PT.Dataset_ID = DS.Dataset_ID '
			set @S = @S + 'WHERE ('
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

			-- Now add jobs in @JobListOverride
			If Len(@JobListOverride) > 0
			Begin
				set @S = @S + ' OR (Job IN (' + @JobListOverride + '))'
			End
			
			set @S = @S + ') As LookupQ'
			set @S = @S + ' WHERE Created_DMS >= ''' + @DateText + ''' '
			set @S = @S +  ' AND Job NOT IN '
			set @S = @S +  ' (SELECT Job FROM T_Analysis_Description)'
			set @S = @S +  ' ORDER BY Job'

			If @PreviewSql <> 0
			Begin
				Print '-- Sql used to import new MS/MS analyses from "' + @peptideDBName + '"'
				Print @S + @CrLf
			End
			--			
			exec (@S)
			--
			select @myError = @result, @myRowcount = @@rowcount
			--
			if @myError  <> 0
			begin
				set @message = 'Could not execute import dynamic SQL'
				set @myError = 40010
				goto Done
			end
			
			Set @entriesAdded = @entriesAdded + @myRowCount
			
			IF @myRowCount > 0 and @infoOnly = 0 And @MissingPeptideDB = 1
			Begin
				-- New jobs were added, but the Peptide DB was unknown
				-- Post an entry to the log, but do not return an error
				Set @message = 'Peptide database ' + @peptideDBName + ' was not found in MT_Main..T_Peptide_Database_List; newly imported Jobs have been assigned a PDB_ID value of 0'
				execute PostLogEntry 'Error', @message, 'ImportNewLCQAnalyses'
				Set @message = ''
			End
		
			DELETE FROM #T_Peptide_Database_List
			WHERE PeptideDBName = @peptideDBName
			
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

		End -- </b>
	End -- </a>

	-- how many rows did we add?
	--
	if @infoOnly = 0
	begin	
		SELECT @endingSize = COUNT(*) FROM T_Analysis_Description
		set @entriesAdded = @endingSize - @startingSize
	end

	set @message = 'ImportNewAnalyses - LCQ: ' + convert(varchar(32), @entriesAdded)

Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

