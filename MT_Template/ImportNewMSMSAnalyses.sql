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
**			09/19/2006 mem - Added support for peptide DBs being located on a separate MTS server, utilizing MT_Main.dbo.PopulatePeptideDBLocationTable to determine DB location given Peptide DB Name
**			11/29/2006 mem - Now adding a line feed character in key places to aid readability when using @PreviewSql = 1
**						   - Updated to support ValidateNewAnalysesUsingProteinCollectionFilters setting Valid to >= 250 if @PreviewSql <> 0
**			12/01/2006 mem - Now using udfParseDelimitedIntegerList to parse @JobListOverride
**			03/14/2007 mem - Changed @JobListOverride parameter from varchar(8000) to varchar(max)
**			05/25/2007 mem - Now calling LookupPeptideDBLocations to determine the location of the peptide databases
**			10/07/2007 mem - Increased size of Protein_Collection_List to varchar(max)
**			08/14/2008 mem - Renamed Organism field to Experiment_Organism in T_Analysis_Description
**			12/08/2008 mem - Added support for a Valid code of 252 from ValidateNewAnalysesUsingProteinCollectionFilters
**			03/25/2010 mem - Added new NET Regression fields
**			07/09/2010 mem - Now showing the dataset name, tool name, and result type when @InfoOnly = 1
**			07/13/2010 mem - Now validating the dataset acquisition length against the ranges defined in T_Process_Config
**						   - Now populating DS_Acq_Length in T_Analysis_Description
**			03/28/2012 mem - Now using parameters MSMS_Job_Minimum and MSMS_Job_Maximum from T_Process_Config (if defined); ignored if @JobListOverride is used
**			04/26/2012 mem - Now showing warnings if jobs in @JobListOverride are not in a Peptide DB, or if those jobs are in a Peptide DB that is not defined in T_Process_Config
**			04/18/2013 mem - Expanded [Organism_DB_Name] in #TmpNewAnalysisJobs to varchar(128)
**			10/10/2013 mem - Now populating MyEMSLState
**			11/07/2013 mem - Now passing @previewSql to ParseFilterList
**
*****************************************************/
(
	@entriesAdded int = 0 output,
	@message varchar(512) = '' output,
	@infoOnly int = 0,
	@JobListOverride varchar(max) = '',
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
	declare @peptideDBServer varchar(128)
	declare @peptideDBPath varchar(256)
	set @peptideDBName = ''
	set @peptideDBServer = ''
	set @peptideDBPath = ''
	
	declare @peptideDBID int
	
	declare @SCampaign varchar(255)
	declare @SAddnl varchar(2000)
	declare @SCampaignAndAddnl varchar(2000)

	declare @S varchar(8000)
	declare @continue tinyint

	declare @filterValueLookupTableName varchar(256)
	declare @filterMatchCount int

	declare @FilterOnEnzymeID tinyint
	
	declare @UsingJobListOverride tinyint
	set @UsingJobListOverride = 0
	
	declare @JobsByDualKeyFilters int
	
	declare @expListCount int
	declare @expListCountExcluded int
	
	declare @datasetListCount int
	declare @datasetListCountExcluded int

	declare @Lf char(1)
	Set @Lf = char(10)
	
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
		PeptideDBName varchar(128) NULL,
		PeptideDBID int NULL,
		PeptideDBServer varchar(128) NULL,
		PeptideDBPath varchar(256) NULL
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
			JobOverride int,
			Dataset varchar(128),
			AnalysisTool varchar(128),
			ResultType varchar(128),
			Completed DateTime,
			Peptide_DB varchar(128),
			Valid_Peptide_DB varchar(32),
			Already_In_MTDB varchar(32)
		)
					
		INSERT INTO #T_Tmp_JobListOverride (JobOverride, Dataset, AnalysisTool, ResultType, Completed, Peptide_DB, Valid_Peptide_DB, Already_In_MTDB)
		SELECT JobListQ.Job,
		       DAJI.Dataset,
		       DAJI.AnalysisTool,
		       DAJI.ResultType,
		       DAJI.Completed,
		       PDM.DB_Name,
		       'No' AS Valid_Peptide_DB,
		       'No' AS Already_In_MTDB
		FROM ( SELECT DISTINCT Value AS Job
		       FROM dbo.udfParseDelimitedIntegerList ( @JobListOverride, ',' ) 
		     ) AS JobListQ
		     LEFT OUTER JOIN MT_Main.dbo.T_DMS_Analysis_Job_Info_Cached DAJI
		       ON JobListQ.Job = DAJI.Job
		     LEFT OUTER JOIN MT_Main.dbo.V_Analysis_Job_to_Peptide_DB_Map_AllServers PDM
		       ON DAJI.Job = PDM.Job
		ORDER BY DAJI.Job, PDM.DB_Name
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Error parsing Job Override list'
			goto Done
		end

		Set @UsingJobListOverride = 1

		-- Look for jobs that are already in T_Analysis_Description
		--
		UPDATE #T_Tmp_JobListOverride
		SET Already_In_MTDB = 'Yes'
		FROM #T_Tmp_JobListOverride Target
		     INNER JOIN T_Analysis_Description TAD
		       ON Target.JobOverride = TAD.Job
		
		---------------------------------------------------------------------------
		-- Validate that the jobs in @JobListOverride are present in a Peptide DB defined in T_Process_Config
		---------------------------------------------------------------------------
		--
		-- First update column Valid_Peptide_DB
		--
		UPDATE #T_Tmp_JobListOverride
		SET Valid_Peptide_DB = 'Yes'
		FROM #T_Tmp_JobListOverride Target
		     INNER JOIN ( SELECT Value
		                  FROM T_Process_Config
		                  WHERE Name = 'Peptide_DB_Name' 
		                ) PeptideDBs
		       ON Target.Peptide_DB = PeptideDBs.Value
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		-- Delete entries from #T_Tmp_JobListOverride where Valid_Peptide_DB = 'No' yet the job has another entry with Valid_Peptide_DB='Yes'
		--
		DELETE FROM #T_Tmp_JobListOverride
		WHERE Valid_Peptide_DB = 'No' AND
		      JobOverride IN ( SELECT JobOverride
		                       FROM #T_Tmp_JobListOverride
		                       WHERE Valid_Peptide_DB = 'Yes' )
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @InfoOnly <> 0
		Begin

			set @S = ''
			set @S = @S + ' SELECT JobListQ.JobOverride,  Dataset, AnalysisTool, ResultType, Completed, Peptide_DB, ' + @Lf
			set @S = @S + ' CASE WHEN Valid_Peptide_DB = ''No'' ' + @Lf
			set @S = @S +      ' THEN CASE WHEN Peptide_DB Is Null ' + @Lf
			set @S = @S +                ' THEN ''Warning, job is not in a peptide DB; confirm that it is a MS/MS job'' ' + @Lf
			set @S = @S +                ' ELSE ''Warning, invalid Peptide_DB; update T_Process_Config'' ' + @Lf
			set @S = @S +                ' END ' + @Lf
			set @S = @S +      ' ELSE CASE WHEN Already_In_MTDB = ''Yes'' ' + @Lf
			set @S = @S +                ' THEN ''Warning, Job already in T_Analysis_Description'' ' + @Lf
			set @S = @S +                ' ELSE '''' ' + @Lf
			set @S = @S +                ' End ' + @Lf
			set @S = @S +      ' END AS Notes ' + @Lf
			set @S = @S + ' FROM #T_Tmp_JobListOverride JobListQ ' + @Lf
			set @S = @S + ' ORDER BY JobListQ.JobOverride' + @Lf

			If @PreviewSql <> 0
			Begin
				Print '-- SQL used to show Datasets and Tool Names for jobs in #T_Tmp_JobListOverride'
				Print @S
			End
				
			Exec (@S)
		End
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
	-- Look for MSMS_Job_Minimum and MSMS_Job_Maximum in T_Process_Config
	-- (ignored if @JobListOverride is defined)
	---------------------------------------------------
	--
	declare @JobMinimum int = 0
	declare @JobMaximum int = 0
	declare @ErrorOccurred tinyint = 0
	
	If @UsingJobListOverride = 0
	Begin
		exec GetProcessConfigValueInt 'MSMS_Job_Minimum', @DefaultValue=0, @ConfigValue=@JobMinimum output, @LogErrors=0, @ErrorOccurred=@ErrorOccurred output
	
		If @ErrorOccurred > 0
		Begin
			Set @message = 'Entry for MSMS_Job_Minimum in T_Process_Config is not numeric; unable to apply job number filter'
			Exec PostLogEntry 'Error', @message, 'ImportNewMSMSAnalyses'
			Goto Done
		End
	
		exec GetProcessConfigValueInt 'MSMS_Job_Maximum', @DefaultValue=0, @ConfigValue=@JobMaximum output, @LogErrors=0, @ErrorOccurred=@ErrorOccurred output
	
		If @ErrorOccurred > 0
		Begin
			Set @message = 'Entry for MSMS_Job_Maximum in T_Process_Config is not numeric; unable to apply job number filter'
			Exec PostLogEntry 'Error', @message, 'ImportNewMSMSAnalyses'
			Goto Done
		End	
	End
	
	---------------------------------------------------
	-- Use the peptide database name(s) in T_Process_Config to populate #T_Peptide_Database_List
	---------------------------------------------------
	--
	Exec @myError = LookupPeptideDBLocations @message = @message output
	
	If @myError <> 0
		Goto Done
	
	---------------------------------------------------
	-- Count the number of Enzyme_ID entries in T_Process_Config
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
	-- Construct the Campaign Sql, plus the Process_State, Organism_DB_Name, Parameter_File_Name, Separation_Sys_Type, and Result_Type Sql
	---------------------------------------------------
	set @SCampaign = ''
	set @SCampaign = @SCampaign + ' Campaign IN ('
	set @SCampaign = @SCampaign +   ' SELECT Value FROM T_Process_Config'
	set @SCampaign = @SCampaign +   ' WHERE [Name] = ''Campaign'' AND Len(Value) > 0)' + @Lf
	
	set @SAddnl = ''
	set @SAddnl = @SAddnl + ' (Process_State = 70)' + @Lf
	
	If @minGANETFit >= 0
		set @SAddnl = @SAddnl + ' AND (ISNULL(GANET_Fit, 0) >= ' + convert(varchar(12), @minGANETFit) + ')' + @Lf
	Else
		set @SAddnl = @SAddnl + ' AND (ISNULL(GANET_RSquared, 0) >= ' + convert(varchar(12), @minGANETRSquared) + ')' + @Lf
		
	set @SAddnl = @SAddnl + ' AND ((Protein_Collection_List <> ''na'' AND Protein_Collection_List <> '''')' + @Lf
	set @SAddnl = @SAddnl + '       OR Organism_DB_Name IN (SELECT Value FROM T_Process_Config'
	set @SAddnl = @SAddnl +       ' WHERE [Name] = ''Organism_DB_File_Name'' AND Len(Value) > 0))' + @Lf

	set @SAddnl = @SAddnl + ' AND Parameter_File_Name IN (SELECT Value FROM T_Process_Config'
	set @SAddnl = @SAddnl +     ' WHERE [Name] = ''Parameter_File_Name'' AND Len(Value) > 0)' + @Lf

	set @SAddnl = @SAddnl + ' AND Separation_Sys_Type IN (SELECT Value FROM T_Process_Config'
	set @SAddnl = @SAddnl +     ' WHERE [Name] = ''Separation_Type'' AND Len(Value) > 0)' + @Lf

	set @SAddnl = @SAddnl + ' AND ResultType IN (SELECT Value FROM T_Process_Config'
	set @SAddnl = @SAddnl +     ' WHERE [Name] = ''MSMS_Result_Type'' AND Len(Value) > 0)' + @Lf

	if @FilterOnEnzymeID = 1
	Begin
		Set @SAddnl = @SAddnl + ' AND Enzyme_ID IN (SELECT Value FROM T_Process_Config'
		Set @SAddnl = @SAddnl +     ' WHERE [Name] = ''Enzyme_ID'' AND Len(Value) > 0)' + @Lf
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
		[Job] int NOT NULL,
		[Dataset] varchar(128) NOT NULL,
		[Dataset_ID] int NOT NULL,
		[Dataset_Created_DMS] datetime NULL,
		[Dataset_Acq_Time_Start] datetime NULL,
		[Dataset_Acq_Time_End] datetime NULL,
		[Dataset_Acq_Length] decimal(9,2) NULL,
		[Dataset_Scan_Count] int NULL,
		[Experiment] varchar(64) NULL,
		[Campaign] varchar(64) NULL,
		[PDB_ID] int NULL,
		[Dataset_SIC_Job] int NULL,
		[Experiment_Organism] varchar(50) NOT NULL,
		[Instrument_Class] varchar(32) NOT NULL,
		[Instrument] varchar(64) NULL,
		[Analysis_Tool] varchar(64) NOT NULL,
		[Parameter_File_Name] varchar(255) NOT NULL,
		[Settings_File_Name] varchar(255) NULL,
		[Organism_DB_Name] varchar(128) NOT NULL,
		[Protein_Collection_List] varchar(max) NOT NULL,
		[Protein_Options_List] varchar(256) NOT NULL,
		[Vol_Client] varchar(128) NOT NULL,
		[Vol_Server] varchar(128) NULL,
		[Storage_Path] varchar(255) NOT NULL,
		[Dataset_Folder] varchar(128) NOT NULL,
		[Results_Folder] varchar(128) NOT NULL,
		[MyEMSLState] tinyint NOT NULL,
		[Completed] datetime NULL,
		[ResultType] varchar(32) NULL,
		[Separation_Sys_Type] varchar(50) NULL,
		[PreDigest_Internal_Std] varchar(50) NULL,
		[PostDigest_Internal_Std] varchar(50) NULL,
		[Dataset_Internal_Std] varchar(50) NULL,
		[Enzyme_ID] int NULL,
		[Labelling] varchar(64) NULL,
		[Created_Peptide_DB] datetime NOT NULL,
		[State] int NOT NULL,
		[GANET_Fit] float NULL,
		[GANET_Slope] float NULL,
		[GANET_Intercept] float NULL,
		[GANET_RSquared] real NULL,
		[ScanTime_NET_Slope] real NULL,
		[ScanTime_NET_Intercept] real NULL,
		[ScanTime_NET_RSquared] real NULL,
		[ScanTime_NET_Fit] real NULL,
		[Regression_Order] tinyint NULL,
		[Regression_Filtered_Data_Count] int NULL,
		[Regression_Equation] varchar(512) NULL,
		[Regression_Equation_XML] varchar(MAX) NULL,
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
		Set @peptideDBName = ''
		Set @peptideDBServer = ''
		Set @peptideDBID = 0
		
		SELECT TOP 1 @peptideDBName = PeptideDBName,
					 @peptideDBServer = PeptideDBServer,
					 @peptideDBID = PeptideDBID,
					 @peptideDBPath = PeptideDBPath
		FROM #T_Peptide_Database_List
		ORDER BY PeptideDBName
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin -- <a>
			---------------------------------------------------
			-- Define the table where we will look up jobs from
			---------------------------------------------------
			
			set @filterValueLookupTableName = @peptideDBPath + '.dbo.T_Analysis_Description'

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

				If @JobMinimum > 0
					DELETE FROM #TmpJobsByDualKeyFilters
					WHERE Job < @JobMinimum

				If @JobMaximum > 0
					DELETE FROM #TmpJobsByDualKeyFilters
					WHERE Job > @JobMaximum
				
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
			Exec @myError = ParseFilterList 'Experiment', @filterValueLookupTableName, 'Experiment', @SCampaignAndAddnl, @filterMatchCount OUTPUT, @PreviewSql=@PreviewSql
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
			Exec @myError = ParseFilterList 'Experiment_Exclusion', @filterValueLookupTableName, 'Experiment', @SCampaignAndAddnl, @PreviewSql=@PreviewSql
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
			Exec @myError = ParseFilterList 'Dataset', @filterValueLookupTableName, 'Dataset', @SCampaignAndAddnl, @filterMatchCount OUTPUT, @PreviewSql=@PreviewSql
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
			Exec @myError = ParseFilterList 'Dataset_Exclusion', @filterValueLookupTableName, 'Dataset', @SCampaignAndAddnl, @PreviewSql=@PreviewSql
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
			set @S = @S + ' Dataset_Created_DMS, Dataset_Acq_Time_Start, Dataset_Acq_Time_End, Dataset_Acq_Length, Dataset_Scan_Count,'
			set @S = @S + ' Experiment, Campaign, PDB_ID,'
			set @S = @S + ' Dataset_SIC_Job, Experiment_Organism, Instrument_Class, Instrument, Analysis_Tool,'
			set @S = @S + ' Parameter_File_Name, Settings_File_Name,'
			set @S = @S + ' Organism_DB_Name, Protein_Collection_List, Protein_Options_List,'
			set @S = @S + ' Vol_Client, Vol_Server, Storage_Path, Dataset_Folder, Results_Folder, MyEMSLState,'
			set @S = @S + ' Completed, ResultType, Separation_Sys_Type,'
			set @S = @S + ' PreDigest_Internal_Std, PostDigest_Internal_Std, Dataset_Internal_Std,'
			set @S = @S + ' Enzyme_ID, Labelling, Created_Peptide_DB, State, '
			set @S = @S + ' GANET_Fit, GANET_Slope, GANET_Intercept, GANET_RSquared,'
			set @S = @S + ' ScanTime_NET_Slope, ScanTime_NET_Intercept, ScanTime_NET_RSquared, ScanTime_NET_Fit,'
			set @S = @S + ' Regression_Order, Regression_Filtered_Data_Count, Regression_Equation, Regression_Equation_XML'
			set @S = @S + ') ' + @Lf
			set @S = @S + 'SELECT DISTINCT * '
			set @S = @S + 'FROM (' + @Lf
			set @S = @S + 'SELECT'
			set @S = @S + '	 PT.Job, PT.Dataset, PT.Dataset_ID,' + @Lf
			set @S = @S + '  DS.Created_DMS, DS.Acq_Time_Start, DS.Acq_Time_End,' + @Lf
			set @S = @S + '  IsNull(DS.Acq_Length, 0) AS Dataset_Acq_Length, DS.Scan_Count,' + @Lf
			set @S = @S + '  PT.Experiment, PT.Campaign, ' + Convert(varchar(11), @peptideDBID) + ' AS PDB_ID,' + @Lf
			set @S = @S + '  DS.SIC_Job, PT.Experiment_Organism, PT.Instrument_Class, PT.Instrument, PT.Analysis_Tool,' + @Lf
			set @S = @S + '  PT.Parameter_File_Name,	PT.Settings_File_Name,' + @Lf
			set @S = @S + '  PT.Organism_DB_Name, PT.Protein_Collection_List, PT.Protein_Options_List,' + @Lf
			set @S = @S + '  PT.Vol_Client, PT.Vol_Server, PT.Storage_Path, PT.Dataset_Folder, PT.Results_Folder, PT.MyEMSLState,' + @Lf
			set @S = @S + '  PT.Completed, PT.ResultType, PT.Separation_Sys_Type,' + @Lf
			set @S = @S + '  PT.PreDigest_Internal_Std, PT.PostDigest_Internal_Std, PT.Dataset_Internal_Std,' + @Lf
			set @S = @S + '  PT.Enzyme_ID, PT.Labelling, PT.Created, 1 AS StateNew,' + @Lf
			set @S = @S + '  PT.GANET_Fit, PT.GANET_Slope, PT.GANET_Intercept, PT.GANET_RSquared,' + @Lf
			set @S = @S + '  PT.ScanTime_NET_Slope, PT.ScanTime_NET_Intercept, PT.ScanTime_NET_RSquared, PT.ScanTime_NET_Fit,' + @Lf
			set @S = @S + '  PT.Regression_Order, PT.Regression_Filtered_Data_Count, PT.Regression_Equation, PT.Regression_Equation_XML' + @Lf
			set @S = @S + 'FROM ' + @Lf
			set @S = @S +   ' ' + @peptideDBPath + '.dbo.T_Analysis_Description AS PT LEFT OUTER JOIN ' + @Lf
			set @S = @S +   ' ' + @peptideDBPath + '.dbo.T_Datasets AS DS ON PT.Dataset_ID = DS.Dataset_ID ' + @Lf

			If @UsingJobListOverride = 1
			Begin
				set @S = @S + ' INNER JOIN #T_Tmp_JobListOverride JobListQ ON PT.Job = JobListQ.JobOverride ' + @Lf
			End
			Else			
			Begin
				set @S = @S + 'WHERE (' + @Lf
					set @S = @S + @SCampaignAndAddnl
					
					if @expListCount > 0
					begin
						set @S = @S + ' AND PT.Experiment IN '
						set @S = @S + '( '
						set @S = @S + '	SELECT Experiment FROM #TmpExperiments '
						set @S = @S + ') ' + @Lf
					end
					
					if @expListCountExcluded > 0
					begin
						set @S = @S + ' AND NOT PT.Experiment IN '
						set @S = @S + '( '
						set @S = @S + '	SELECT Experiment FROM #TmpExperimentsExcluded '
						set @S = @S + ') ' + @Lf
					End

					if @datasetListCount > 0
					begin
						set @S = @S + ' AND PT.Dataset IN '
						set @S = @S + '( '
						set @S = @S + '	SELECT Dataset FROM #TmpDatasets '
						set @S = @S + ') ' + @Lf
					end

					if @datasetListCountExcluded > 0
					begin
						set @S = @S + ' AND NOT PT.Dataset IN '
						set @S = @S + '( '
						set @S = @S + '	SELECT Dataset FROM #TmpDatasetsExcluded '
						set @S = @S + ') ' + @Lf
					end
					
					if @AcqLengthFilterEnabled > 0
					begin
						Set @S = @S + ' AND IsNull(DS.Acq_Length, 0) BETWEEN '
						Set @S = @S +     Convert(varchar(12), @AcqLengthMinimum) + ' AND '
						Set @S = @S +     Convert(varchar(12), @AcqLengthMaximum) + @Lf
					end
					
					If @JobMinimum > 0
					begin
						Set @S = @S + ' AND PT.Job >= ' + Convert(varchar(12), @JobMinimum) + @Lf
					end
					
					If @JobMaximum > 0
					begin
						Set @S = @S + ' AND PT.Job <= ' + Convert(varchar(12), @JobMaximum) + @Lf
					end
	
				set @S = @S + ')'
					
				-- Now add jobs found using the alternate job selection method
				If @JobsByDualKeyFilters > 0
				Begin
					set @S = @S + ' OR (Job IN (SELECT Job FROM #TmpJobsByDualKeyFilters)) ' + @Lf
				End
			End
			
			set @S = @S + ') As LookupQ' + @Lf
			set @S = @S + ' WHERE Job NOT IN (SELECT Job FROM T_Analysis_Description)' + @Lf
			
			If @UsingJobListOverride = 0 And Len(@DateText) > 0
				set @S = @S + ' AND Created_DMS >= ''' + @DateText + '''' + @Lf
				
			set @S = @S +  ' ORDER BY Job'

			If @PreviewSql <> 0
			Begin
				Print '-- Sql used to import new MS/MS analyses from "' + @peptideDBPath + '"'
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
				WHERE Protein_Collection_List = 'na' OR IsNull(Protein_Collection_List, '') = '' OR Protein_Collection_List = '(na)'
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
			End

			-- Validate all jobs with Valid = 0 against the Protein Collection 
			--  filters defined in T_Process_Config
			-- If @PreviewSql is non-zero, then will update Valid to 1 for Valid jobs and to a valid >= 250 for Invalid jobs
			Exec @myError = ValidateNewAnalysesUsingProteinCollectionFilters @PreviewSql, @message = @message output
			
			If @myError <> 0
				Goto Done

			-- Display the contents of #TmpNewAnalysisJobs (if not empty)
			If Exists (SELECT TOP 1 * FROM #TmpNewAnalysisJobs)
			Begin
				If @PreviewSql <> 0
				Begin
					If Exists (SELECT TOP 1 * FROM #TmpNewAnalysisJobs WHERE Valid >= 250)
					Begin
						SELECT CASE WHEN Valid = 250 THEN 'No Valid Collection Names'
									WHEN Valid = 251 THEN 'Incompatible Protein Options'
									WHEN Valid = 252 THEN 'T_Process_Config has no Protein_Collection_Filter entries'
									ELSE 'Unknown exclusion reason'
								END As Exclusion_Reason, *
						FROM #TmpNewAnalysisJobs
						WHERE Valid >= 250
						ORDER BY Job
						
						DELETE FROM #TmpNewAnalysisJobs
						WHERE Valid >= 250
					End
				End

				If @infoOnly = 0
					-- Copy the new jobs from #TmpNewAnalysisJobs to T_Analysis_Description
					INSERT INTO T_Analysis_Description (
						Job, Dataset, Dataset_ID, Dataset_Created_DMS, 
						Dataset_Acq_Time_Start, Dataset_Acq_Time_End, Dataset_Acq_Length, Dataset_Scan_Count, 
						Experiment, Campaign, PDB_ID, Dataset_SIC_Job, 
						Experiment_Organism, Instrument_Class, Instrument, 
						Analysis_Tool, Parameter_File_Name, Settings_File_Name, 
						Organism_DB_Name, Protein_Collection_List, Protein_Options_List, 
						Vol_Client, Vol_Server, Storage_Path, Dataset_Folder, Results_Folder, MyEMSLState,
						Completed, ResultType, Separation_Sys_Type, 
						PreDigest_Internal_Std, PostDigest_Internal_Std, 
						Dataset_Internal_Std, Enzyme_ID, Labelling, Created_Peptide_DB,
						GANET_Fit, GANET_Slope, GANET_Intercept, GANET_RSquared, ScanTime_NET_Slope, 
						ScanTime_NET_Intercept, ScanTime_NET_RSquared, ScanTime_NET_Fit,
						Regression_Order, Regression_Filtered_Data_Count, Regression_Equation, Regression_Equation_XML
						)				
					SELECT 
						Job, Dataset, Dataset_ID, Dataset_Created_DMS, 
						Dataset_Acq_Time_Start, Dataset_Acq_Time_End, Dataset_Acq_Length, Dataset_Scan_Count, 
						Experiment, Campaign, PDB_ID, Dataset_SIC_Job, 
						Experiment_Organism, Instrument_Class, Instrument, 
						Analysis_Tool, Parameter_File_Name, Settings_File_Name, 
						Organism_DB_Name, Protein_Collection_List, Protein_Options_List, 
						Vol_Client, Vol_Server, Storage_Path, Dataset_Folder, Results_Folder, MyEMSLState,
						Completed, ResultType, Separation_Sys_Type, 
						PreDigest_Internal_Std, PostDigest_Internal_Std, 
						Dataset_Internal_Std, Enzyme_ID, Labelling, Created_Peptide_DB,
						GANET_Fit, GANET_Slope, GANET_Intercept, GANET_RSquared, ScanTime_NET_Slope, 
						ScanTime_NET_Intercept, ScanTime_NET_RSquared, ScanTime_NET_Fit,
						Regression_Order, Regression_Filtered_Data_Count, Regression_Equation, Regression_Equation_XML
					FROM #TmpNewAnalysisJobs 
				Else
					SELECT *
					FROM #TmpNewAnalysisJobs
					ORDER BY Job
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
				
				Set @entriesAdded = @entriesAdded + @myRowCount
				
				If @myRowCount > 0 and @infoOnly = 0 And @peptideDBID = 0
				Begin
					-- New jobs were added, but the Peptide DB ID was unknown
					-- Post an entry to the log, but do not return an error
					Set @message = 'Peptide database ' + @peptideDBName + ' was not found in MT_Main.dbo.T_Peptide_Database_List on server ' + @peptideDBServer + '; newly imported Jobs have been assigned a PDB_ID value of 0'
					execute PostLogEntry 'Error', @message, 'ImportNewMSMSAnalyses'
					Set @message = ''
				End
			End
					
			DELETE FROM #T_Peptide_Database_List
			WHERE PeptideDBName = @peptideDBName
			
			If @PreviewSql <> 0
			Begin
				If Exists (SELECT TOP 1 * FROM #PreviewSqlData)
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
	If @myError <> 0 and @infoOnly = 0
	Begin
		execute PostLogEntry 'Error', @message, 'ImportNewMSMSAnalyses'
	End


	return @myError


GO
GRANT EXECUTE ON [dbo].[ImportNewMSMSAnalyses] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ImportNewMSMSAnalyses] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ImportNewMSMSAnalyses] TO [MTS_DB_Lite] AS [dbo]
GO
