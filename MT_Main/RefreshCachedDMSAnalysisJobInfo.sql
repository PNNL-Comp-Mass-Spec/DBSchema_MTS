/****** Object:  StoredProcedure [dbo].[RefreshCachedDMSAnalysisJobInfo] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE RefreshCachedDMSAnalysisJobInfo
/****************************************************
**
**	Desc:	Updates the data in T_DMS_Analysis_Job_Info_Cached using DMS
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	05/09/2007 - See Ticket:422
**			10/03/2007 mem - Now populating the Processor column
**			10/05/2007 mem - Updated ProteinCollectionList to varchar(max)
**			08/07/2008 mem - Added parameter @SourceMTSServer; if provided, then contacts that server rather than contacting DMS.
**			09/18/2008 mem - Now passing @FullRefreshPerformed and @LastRefreshMinimumID to UpdateDMSCachedDataStatus
**			03/13/2010 mem - Added parameter @UpdateSourceMTSServer
**			07/13/2010 mem - Expanded Comment to varchar(512)
**						   - Now populating DS_Acq_Length
**			08/02/2010 mem - Updated to use a single-step MERGE statement instead of three separate Delete, Update, and Insert statements
**			09/24/2010 mem - Now populating RequestID
**			01/19/2011 mem - Now casting DS_Acq_Length to decimal(9, 2) when querying @SourceTable
**						   - Added parameter @ShowActionTable
**			06/21/2013 mem - Changed default value of @SourceMTSServer to be blank
**			10/10/2013 mem - Now updating MyEMSLState
**			09/23/2014 mem - Now treating error 53 as a warning (Named Pipes Provider: Could not open a connection to SQL Server)
**			04/27/2016 mem - Now treating negative values for @JobMinimum or @JobMaximum as 0
**
*****************************************************/
(
	@JobMinimum int = 0,						-- Set to a positive value to limit the jobs examined; when non-zero, then jobs outside this range are ignored
	@JobMaximum int = 0,
	@SourceMTSServer varchar(128) = '',			-- MTS Server to look at to get this information from (in the MT_Main database); if blank, then uses V_DMS_Dataset_Import_Ex to directly query Gigasax
	@UpdateSourceMTSServer tinyint = 0,			-- If 1, then first calls RefreshCachedDMSAnalysisJobInfo on the source MTS server; only valid if @SourceMTSServer is not blank
	@message varchar(255) = '' output,
	@previewSql tinyint = 0,
	@ShowActionTable tinyint = 0				-- Displays the contents of #Tmp_UpdateSummary; ignored if @previewSql is non-zero
)
AS

	Set NoCount On

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	set @message = ''

	Declare @MaxInt int = 2147483647

	Declare @DeleteCount int = 0
	Declare @UpdateCount int = 0
	Declare @InsertCount int = 0

	Declare @FullRefreshPerformed tinyint
	
	Declare @SourceTable varchar(256)
	Declare @S varchar(max)
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'
	
	---------------------------------------------------
	-- Create the temporary table that will be used to
	-- track the number of inserts, updates, and deletes 
	-- performed by the MERGE statement
	---------------------------------------------------
	
	CREATE TABLE #Tmp_UpdateSummary (
		UpdateAction varchar(32),
		Job int null
	)
	
	Begin Try
		Set @CurrentLocation = 'Validate the inputs'

		-- Validate the inputs
		Set @JobMinimum = IsNull(@JobMinimum, 0)
		Set @JobMaximum = IsNull(@JobMaximum, 0)
		Set @SourceMTSServer = IsNull(@SourceMTSServer, '')
		Set @UpdateSourceMTSServer = IsNull(@UpdateSourceMTSServer, 0)
		Set @previewSql = IsNull(@previewSql, 0)
		
		If @JobMinimum <= 0 AND @JobMaximum <= 0
		Begin
			Set @FullRefreshPerformed = 1
			Set @JobMinimum = -@MaxInt
			Set @JobMaximum = @MaxInt
		End
		Else
		Begin
			Set @FullRefreshPerformed = 0
			If @JobMinimum > @JobMaximum
				Set @JobMaximum = @MaxInt
		End

		-- Source server cannot be this server; if they match, set @SourceMTSServer to ''
		If @SourceMTSServer = @@ServerName
			Set @SourceMTSServer = ''

		If @SourceMTSServer <> '' And @UpdateSourceMTSServer <> 0
		Begin
			Set @CurrentLocation = 'Call RefreshCachedDMSAnalysisJobInfo on server ' + @SourceMTSServer

			-- Call RefreshCachedDMSAnalysisJobInfo on server @SourceMTSServer
			Set @S = 'exec ' + @SourceMTSServer + '.MT_Main.dbo.RefreshCachedDMSAnalysisJobInfo ' + Convert(varchar(12), @JobMinimum) + ', ' +  + Convert(varchar(12), @JobMaximum)
			
			If @previewSql <> 0
				Print @S
			Else
				Exec (@S)

		End
		
		If @SourceMTSServer <> ''
			Set @SourceTable = @SourceMTSServer + '.MT_Main.dbo.T_DMS_Analysis_Job_Info_Cached'
		Else
			Set @SourceTable = 'V_DMS_Analysis_Job_Import_Ex'


		Set @CurrentLocation = 'Update Last_Refreshed in T_DMS_Cached_Data_Status'
		-- 
		Exec UpdateDMSCachedDataStatus 'T_DMS_Analysis_Job_Info_Cached', @IncrementRefreshCount = 0, @FullRefreshPerformed = @FullRefreshPerformed, @LastRefreshMinimumID = @JobMinimum


		Set @CurrentLocation = 'Merge data into T_DMS_Analysis_Job_Info_Cached'

		-- Use a MERGE Statement to synchronize T_DMS_Analysis_Job_Info_Cached with @SourceTable
		--
		Set @S = ''
		Set @S = @S + ' MERGE T_DMS_Analysis_Job_Info_Cached AS target'
		Set @S = @S + ' USING (SELECT Job, Priority, Dataset, Experiment, Campaign, DatasetID, '
		Set @S = @S +               ' Organism, InstrumentName, InstrumentClass, AnalysisTool, Processor,'
		Set @S = @S +               ' Completed, ParameterFileName, SettingsFileName, '
		Set @S = @S +               ' OrganismDBName, ProteinCollectionList, ProteinOptions, '
		Set @S = @S +               ' StoragePathClient, StoragePathServer, DatasetFolder, '
		Set @S = @S +               ' ResultsFolder, MyEMSLState, Owner, Comment, SeparationSysType, '
		Set @S = @S +               ' ResultType, [Dataset Int Std], DS_created, '
		Set @S = @S +               ' Convert(decimal(9, 2), DS_Acq_Length), EnzymeID, '
		Set @S = @S +               ' Labelling, [PreDigest Int Std], [PostDigest Int Std], RequestID'
		Set @S = @S +        ' FROM ' + @SourceTable
		Set @S = @S +        ' WHERE Job >= ' + Convert(varchar(12), @JobMinimum) + ' AND Job <= ' + Convert(varchar(12), @JobMaximum)
		Set @S = @S + '	) AS Source ( Job, Priority, Dataset, Experiment, Campaign, DatasetID, '
		Set @S = @S +               ' Organism, InstrumentName, InstrumentClass, AnalysisTool, Processor,'
		Set @S = @S +               ' Completed, ParameterFileName, SettingsFileName, '
		Set @S = @S +               ' OrganismDBName, ProteinCollectionList, ProteinOptions, '
		Set @S = @S +               ' StoragePathClient, StoragePathServer, DatasetFolder, '
		Set @S = @S +               ' ResultsFolder, MyEMSLState, Owner, Comment, SeparationSysType, '
		Set @S = @S +               ' ResultType, [Dataset Int Std], DS_created, DS_Acq_Length, EnzymeID, '
		Set @S = @S +               ' Labelling, [PreDigest Int Std], [PostDigest Int Std], RequestID)'
		Set @S = @S + ' ON (target.Job = source.Job)'
		Set @S = @S + ' WHEN Matched AND ( 	Target.RequestID <> source.RequestID OR'
		Set @S = @S +                     ' Target.Priority <> source.Priority OR'
		Set @S = @S +                     ' Target.Dataset <> source.Dataset OR'
		Set @S = @S +                     ' Target.Experiment <> source.Experiment OR'
		Set @S = @S +                     ' Target.Campaign <> source.Campaign OR'
		Set @S = @S +                     ' Target.DatasetID <> source.DatasetID OR'
		Set @S = @S +                     ' Target.Organism <> source.Organism OR'
		Set @S = @S +                     ' IsNull(Target.InstrumentName, '''') <> IsNull(source.InstrumentName, '''') OR'
		Set @S = @S +                     ' IsNull(Target.InstrumentClass, '''') <> IsNull(source.InstrumentClass, '''') OR'
		Set @S = @S +                     ' Target.AnalysisTool <> source.AnalysisTool OR'
		Set @S = @S +                     ' IsNull(Target.Processor, '''') <> IsNull(source.Processor, '''') OR'
		Set @S = @S +                     ' IsNull(Target.Completed, ''1/1/1980'') <> IsNull(source.Completed, ''1/1/1980'') OR'
		Set @S = @S +                     ' Target.ParameterFileName <> source.ParameterFileName OR'
		Set @S = @S +                     ' IsNull(Target.SettingsFileName, '''') <> IsNull(source.SettingsFileName, '''') OR'
		Set @S = @S +         ' Target.OrganismDBName <> source.OrganismDBName OR'
		Set @S = @S +    ' Target.ProteinCollectionList <> source.ProteinCollectionList OR'
		Set @S = @S +                     ' Target.ProteinOptions <> source.ProteinOptions OR'
		Set @S = @S +                     ' Target.StoragePathClient <> source.StoragePathClient OR'
		Set @S = @S +                     ' IsNull(Target.StoragePathServer, '''') <> IsNull(source.StoragePathServer, '''') OR'
		Set @S = @S +                     ' IsNull(Target.DatasetFolder, '''') <> IsNull(source.DatasetFolder, '''') OR'
		Set @S = @S +                     ' IsNull(Target.ResultsFolder, '''') <> IsNull(source.ResultsFolder, '''') OR'
		Set @S = @S +                     ' Target.MyEMSLState <> source.MyEMSLState OR'
		Set @S = @S +                     ' IsNull(Target.Owner, '''') <> IsNull(source.Owner, '''') OR'
		Set @S = @S +                     ' IsNull(Target.Comment, '''') <> IsNull(source.Comment, '''') OR'
		Set @S = @S +                     ' IsNull(Target.SeparationSysType, '''') <> IsNull(source.SeparationSysType, '''') OR'
		Set @S = @S +                     ' IsNull(Target.ResultType, '''') <> IsNull(source.ResultType, '''') OR'
		Set @S = @S +                     ' IsNull(Target.[Dataset Int Std], '''') <> IsNull(source.[Dataset Int Std], '''') OR'
		Set @S = @S +                     ' Target.DS_created <> source.DS_created OR'
		Set @S = @S +                     ' IsNull(Target.DS_Acq_Length, 0) <> IsNull(source.DS_Acq_Length, 0) OR'
		Set @S = @S +                     ' Target.EnzymeID <> source.EnzymeID OR'
		Set @S = @S +                     ' IsNull(Target.Labelling, '''') <> IsNull(source.Labelling, '''') OR'
		Set @S = @S +                     ' Target.[PreDigest Int Std] <> source.[PreDigest Int Std] OR'
		Set @S = @S +                     ' Target.[PostDigest Int Std] <> source.[PostDigest Int Std] ) THEN '
		Set @S = @S + '	UPDATE set RequestID = source.RequestID,'
		Set @S = @S +            ' Priority = source.Priority,'
		Set @S = @S +            ' Dataset = source.Dataset,'
		Set @S = @S +            ' Experiment = source.Experiment,'
		Set @S = @S +            ' Campaign = source.Campaign,'
		Set @S = @S +            ' DatasetID = source.DatasetID,'
		Set @S = @S +            ' Organism = source.Organism,'
		Set @S = @S +            ' InstrumentName = source.InstrumentName,'
		Set @S = @S +            ' InstrumentClass = source.InstrumentClass,'
		Set @S = @S +            ' AnalysisTool = source.AnalysisTool,'
		Set @S = @S +            ' Processor = source.Processor,'
		Set @S = @S +            ' Completed = source.Completed,'
		Set @S = @S +            ' ParameterFileName = source.ParameterFileName,'
		Set @S = @S +            ' SettingsFileName = source.SettingsFileName,'
		Set @S = @S +            ' OrganismDBName = source.OrganismDBName,'
		Set @S = @S +            ' ProteinCollectionList = source.ProteinCollectionList,'
		Set @S = @S +            ' ProteinOptions = source.ProteinOptions,'
		Set @S = @S +            ' StoragePathClient = source.StoragePathClient,'
		Set @S = @S +            ' StoragePathServer = source.StoragePathServer,'
		Set @S = @S +            ' DatasetFolder = source.DatasetFolder,'
		Set @S = @S +            ' ResultsFolder = source.ResultsFolder,'
		Set @S = @S +            ' MyEMSLState = source.MyEMSLState,'
		Set @S = @S +            ' Owner = source.Owner,'
		Set @S = @S +            ' Comment = source.Comment,'
		Set @S = @S +            ' SeparationSysType = source.SeparationSysType,'
		Set @S = @S +            ' ResultType = source.ResultType,'
		Set @S = @S +            ' [Dataset Int Std] = source.[Dataset Int Std],'
		Set @S = @S +            ' DS_created = source.DS_created,'
		Set @S = @S +            ' DS_Acq_Length = source.DS_Acq_Length,'
		Set @S = @S +            ' EnzymeID = source.EnzymeID,'
		Set @S = @S +            ' Labelling = source.Labelling,'
		Set @S = @S +            ' [PreDigest Int Std] = source.[PreDigest Int Std],'
		Set @S = @S +            ' [PostDigest Int Std] = source.[PostDigest Int Std],'
		Set @S = @S +            ' Last_Affected = GetDate()'
		Set @S = @S + ' WHEN Not Matched THEN'
		Set @S = @S + '	INSERT (Job, RequestID, Priority, Dataset, Experiment, Campaign, DatasetID, '
		Set @S = @S +         ' Organism, InstrumentName, InstrumentClass, AnalysisTool, Processor,'
		Set @S = @S +         ' Completed, ParameterFileName, SettingsFileName, '
		Set @S = @S +         ' OrganismDBName, ProteinCollectionList, ProteinOptions, '
		Set @S = @S +         ' StoragePathClient, StoragePathServer, DatasetFolder, '
		Set @S = @S +         ' ResultsFolder, MyEMSLState, Owner, Comment, SeparationSysType, '
		Set @S = @S +         ' ResultType, [Dataset Int Std], DS_created, DS_Acq_Length, EnzymeID, '
		Set @S = @S +         ' Labelling, [PreDigest Int Std], [PostDigest Int Std], Last_Affected)'
		Set @S = @S + '	VALUES ( source.Job, source.RequestID, source.Priority, source.Dataset, source.Experiment, source.Campaign, source.DatasetID, '
		Set @S = @S +         '  source.Organism, source.InstrumentName, source.InstrumentClass, source.AnalysisTool, source.Processor,'
		Set @S = @S +         '  source.Completed, source.ParameterFileName, source.SettingsFileName, '
		Set @S = @S +         '  source.OrganismDBName, source.ProteinCollectionList, source.ProteinOptions, '
		Set @S = @S +         '  source.StoragePathClient, source.StoragePathServer, source.DatasetFolder, '
		Set @S = @S +         '  source.ResultsFolder, source.MyEMSLState, source.Owner, source.Comment, source.SeparationSysType, '
		Set @S = @S +         '  source.ResultType, source.[Dataset Int Std], source.DS_created, source.DS_Acq_Length, source.EnzymeID, '
		Set @S = @S +         '  source.Labelling, source.[PreDigest Int Std], source.[PostDigest Int Std], GetDate())'
		Set @S = @S + ' WHEN NOT MATCHED BY SOURCE AND '
		Set @S = @S + '    Target.Job >= ' + Convert(varchar(12), @JobMinimum) + ' AND Target.Job <= ' + Convert(varchar(12), @JobMaximum) + ' THEN'
		Set @S = @S + '	DELETE'
		Set @S = @S + ' OUTPUT $action, IsNull(inserted.job, deleted.job) INTO #Tmp_UpdateSummary'
		Set @S = @S + ';'

		if @PreviewSql <> 0
			Print @S
		Else
			Exec (@S)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @PreviewSql = 0 And @ShowActionTable <> 0
		Begin
			SELECT *
			FROM #Tmp_UpdateSummary
		End

		If @myError <> 0
		Begin
			set @message = 'Error merging ' + @SourceTable + ' with T_DMS_Analysis_Job_Info_Cached (ErrorID = ' + Convert(varchar(12), @myError) + ')'
			execute PostLogEntry 'Error', @message, 'RefreshCachedDMSAnalysisJobInfo'
		End
		Else
		Begin

			-- Update the stats in T_DMS_Cached_Data_Status
			exec RefreshCachedDMSInfoFinalize 'RefreshCachedDMSAnalysisJobInfo', @SourceTable, 'T_DMS_Analysis_Job_Info_Cached',
												@IncrementRefreshCount = 1, 
												@FullRefreshPerformed = @FullRefreshPerformed, 
												@LastRefreshMinimumID = @JobMinimum
		End
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RefreshCachedDMSAnalysisJobInfo')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList=53,
								@ErrorNum = @myError output, @message = @message output
		Goto Done		
	End Catch
			
Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[RefreshCachedDMSAnalysisJobInfo] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RefreshCachedDMSAnalysisJobInfo] TO [MTS_DB_Lite] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[RefreshCachedDMSAnalysisJobInfo] TO [MTUser] AS [dbo]
GO
