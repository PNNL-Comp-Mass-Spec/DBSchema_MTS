/****** Object:  StoredProcedure [dbo].[RefreshCachedDMSAnalysisJobInfo] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.RefreshCachedDMSAnalysisJobInfo
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
**
*****************************************************/
(
	@JobMinimum int = 0,		-- Set to a positive value to limit the jobs examined; when non-zero, then jobs outside this range are ignored
	@JobMaximum int = 0,
	@SourceMTSServer varchar(128) = 'porky',	-- MTS Server to look at to get this information from (in the MT_Main database); if blank, then uses V_DMS_Analysis_Job_Import_Ex
	@UpdateSourceMTSServer tinyint = 0,			-- If 1, then first calls RefreshCachedDMSAnalysisJobInfo on the source MTS server; only valid if @SourceMTSServer is not blank
	@message varchar(255) = '' output,
	@previewSql tinyint = 0
)
AS

	Set NoCount On

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	set @message = ''

	Declare @MaxInt int
	Set @MaxInt = 2147483647

	Declare @DeleteCount int
	Declare @UpdateCount int
	Declare @InsertCount int
	Set @DeleteCount = 0
	Set @UpdateCount = 0
	Set @InsertCount = 0
	
	Declare @FullRefreshPerformed tinyint
	
	Declare @SourceTable varchar(256)
	Declare @S varchar(max)
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'
	
	Begin Try
		Set @CurrentLocation = 'Validate the inputs'

		-- Validate the inputs
		Set @JobMinimum = IsNull(@JobMinimum, 0)
		Set @JobMaximum = IsNull(@JobMaximum, 0)
		Set @SourceMTSServer = IsNull(@SourceMTSServer, '')
		Set @UpdateSourceMTSServer = IsNull(@UpdateSourceMTSServer, 0)
		Set @previewSql = IsNull(@previewSql, 0)
		
		If @JobMinimum = 0 AND @JobMaximum = 0
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

		Set @CurrentLocation = 'Update T_DMS_Cached_Data_Status'
		-- 
		Exec UpdateDMSCachedDataStatus 'T_DMS_Analysis_Job_Info_Cached', @IncrementRefreshCount = 0, @FullRefreshPerformed = @FullRefreshPerformed, @LastRefreshMinimumID = @JobMinimum

		-- Source server cannot be this server; if they match, set @SourceMTSServer to ''
		If @SourceMTSServer = @@ServerName
			Set @SourceMTSServer = ''

		If @SourceMTSServer <> '' And @UpdateSourceMTSServer <> 0
		Begin
			-- Call RefreshCachedDMSAnalysisJobInfo on server @SourceMTSServer
			Set @S = 'exec ' + @SourceMTSServer + '.MT_Main.dbo.RefreshCachedDMSAnalysisJobInfo ' + Convert(varchar(12), @JobMinimum) + ', ' +  + Convert(varchar(12), @JobMaximum)
			
			If @previewSql <> 0
				Print @S
			Else
				Exec (@S)

		End
		
		Set @CurrentLocation = 'Create #Tmp_DMS_Analysis_Job_Import_Ex'

		-- Since we need to scan the contents of V_DMS_Analysis_Job_Import_Ex three times, we'll first
		-- populate a local temporary table using its contents
		CREATE TABLE #Tmp_DMS_Analysis_Job_Import_Ex (
			Job int NOT NULL,
			Priority int NOT NULL,
			Dataset varchar(128) NOT NULL,
			Experiment varchar(128) NOT NULL,
			Campaign varchar(128) NOT NULL,
			DatasetID int NOT NULL,
			Organism varchar(128) NOT NULL,
			InstrumentName varchar(64) NULL,
			InstrumentClass varchar(64) NULL,
			AnalysisTool varchar(64) NOT NULL,
			Processor varchar(128) NULL,
			Completed datetime NULL,
			ParameterFileName varchar(255) NOT NULL,
			SettingsFileName varchar(255) NULL,
			OrganismDBName varchar(64) NOT NULL,
			ProteinCollectionList varchar(max) NOT NULL,
			ProteinOptions varchar(256) NOT NULL,
			StoragePathClient varchar(8000) NOT NULL,
			StoragePathServer varchar(4096) NULL,
			DatasetFolder varchar(128) NULL,
			ResultsFolder varchar(128) NULL,
			Owner varchar(64) NULL,
			Comment varchar(255) NULL,
			SeparationSysType varchar(64) NULL,
			ResultType varchar(64) NULL,
			[Dataset Int Std] varchar(64) NOT NULL,
			DS_created datetime NOT NULL,
			EnzymeID int NOT NULL,
			Labelling varchar(64) NULL,
			[PreDigest Int Std] varchar(64) NOT NULL,
			[PostDigest Int Std] varchar(64) NOT NULL
		)
		
		-- Create a clustered index on Job
		CREATE CLUSTERED INDEX #IX_Tmp_DMS_Analysis_Job_Import_Ex ON #Tmp_DMS_Analysis_Job_Import_Ex (Job)

		If @SourceMTSServer <> ''
			Set @SourceTable = @SourceMTSServer + '.MT_Main.dbo.T_DMS_Analysis_Job_Info_Cached'
		Else
			Set @SourceTable = 'V_DMS_Analysis_Job_Import_Ex'
			
		Set @CurrentLocation = 'Populate a temporary table with the data in ' + @SourceTable

		-- Construct the Sql to populate #Tmp_DMS_Analysis_Job_Import_Ex
		Set @S = ''
		Set @S = @S + ' INSERT INTO #Tmp_DMS_Analysis_Job_Import_Ex ('
		Set @S = @S +   ' Job, Priority, Dataset, Experiment, Campaign, DatasetID, '
		Set @S = @S +   ' Organism, InstrumentName, InstrumentClass, AnalysisTool, Processor,'
		Set @S = @S +   ' Completed, ParameterFileName, SettingsFileName, '
		Set @S = @S +   ' OrganismDBName, ProteinCollectionList, ProteinOptions, '
		Set @S = @S +   ' StoragePathClient, StoragePathServer, DatasetFolder, '
		Set @S = @S +   ' ResultsFolder, Owner, Comment, SeparationSysType, '
		Set @S = @S +   ' ResultType, [Dataset Int Std], DS_created, EnzymeID, '
		Set @S = @S +   ' Labelling, [PreDigest Int Std], [PostDigest Int Std])'

		If @SourceMTSServer <> ''
		Begin
			Set @S = @S + ' SELECT Job, Priority, Dataset, Experiment, Campaign, DatasetID, '
			Set @S = @S +   ' Organism, InstrumentName, InstrumentClass, AnalysisTool, Processor, '
			Set @S = @S +   ' Completed, ParameterFileName, SettingsFileName, OrganismDBName, ProteinCollectionList, ProteinOptions, '
			Set @S = @S +   ' StoragePathClient, StoragePathServer, DatasetFolder, '
			Set @S = @S +   ' ResultsFolder, Owner, Comment, SeparationSysType, '
			Set @S = @S +   ' ResultType, [Dataset Int Std], DS_created, EnzymeID, '
			Set @S = @S +   ' Labelling, [PreDigest Int Std], [PostDigest Int Std]'
			Set @S = @S + ' FROM ' + @SourceTable
		End
		Else
		Begin
			Set @S = @S + ' SELECT Job, Priority, Dataset, Experiment, Campaign, DatasetID, '
			Set @S = @S +   ' Organism, InstrumentName, InstrumentClass, AnalysisTool, Processor,'
			Set @S = @S +   ' Completed, ParameterFileName, SettingsFileName, '
			Set @S = @S +   ' OrganismDBName, ProteinCollectionList, ProteinOptions, '
			Set @S = @S +   ' StoragePathClient, StoragePathServer, DatasetFolder, '
			Set @S = @S +   ' ResultsFolder, Owner, Comment, SeparationSysType, '
			Set @S = @S +   ' ResultType, [Dataset Int Std], DS_created, EnzymeID,'
			Set @S = @S +   ' Labelling, [PreDigest Int Std], [PostDigest Int Std]'
			Set @S = @S + ' FROM ' + @SourceTable
		End		

		Set @S = @S + ' WHERE Job >= ' + Convert(varchar(12), @JobMinimum) + ' AND Job <= ' + Convert(varchar(12), @JobMaximum)
		
		If @previewSql <> 0
		Begin
			Print @S
			Goto Done
		End
		Else
			Exec (@S)
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error

		
		Set @CurrentLocation = 'Delete extra rows in T_DMS_Analysis_Job_Info_Cached'
		-- 
		DELETE T_DMS_Analysis_Job_Info_Cached 
		FROM T_DMS_Analysis_Job_Info_Cached Target LEFT OUTER JOIN
			 #Tmp_DMS_Analysis_Job_Import_Ex Src ON Target.Job = Src.Job
		WHERE (Src.Job IS NULL) AND
			  Target.Job >= @JobMinimum AND Target.Job <= @JobMaximum
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error
		Set @DeleteCount = @myRowCount
		
		If @DeleteCount > 0
			Set @message = 'Deleted ' + convert(varchar(12), @DeleteCount) + ' extra rows'
			
		Set @CurrentLocation = 'Update existing rows in T_DMS_Analysis_Job_Info_Cached'
		--
		UPDATE T_DMS_Analysis_Job_Info_Cached
		SET Priority = Src.Priority,
			Dataset = Src.Dataset,
			Experiment = Src.Experiment,
			Campaign = Src.Campaign,
			DatasetID = Src.DatasetID,
			Organism = Src.Organism,
			InstrumentName = Src.InstrumentName,
			InstrumentClass = Src.InstrumentClass,
			AnalysisTool = Src.AnalysisTool,
			Processor = Src.Processor,
			Completed = Src.Completed,
			ParameterFileName = Src.ParameterFileName,
			SettingsFileName = Src.SettingsFileName,
			OrganismDBName = Src.OrganismDBName,
			ProteinCollectionList = Src.ProteinCollectionList,
			ProteinOptions = Src.ProteinOptions,
			StoragePathClient = Src.StoragePathClient,
			StoragePathServer = Src.StoragePathServer,
			DatasetFolder = Src.DatasetFolder,
			ResultsFolder = Src.ResultsFolder,
			Owner = Src.Owner,
			Comment = Src.Comment,
			SeparationSysType = Src.SeparationSysType,
			ResultType = Src.ResultType,
			[Dataset Int Std] = Src.[Dataset Int Std],
			DS_created = Src.DS_created,
			EnzymeID = Src.EnzymeID,
			Labelling = Src.Labelling,
			[PreDigest Int Std] = Src.[PreDigest Int Std],
			[PostDigest Int Std] = Src.[PostDigest Int Std],
			Last_Affected = GetDate()
		FROM T_DMS_Analysis_Job_Info_Cached Target INNER JOIN
			 #Tmp_DMS_Analysis_Job_Import_Ex Src ON Target.Job = Src.Job
		WHERE Target.Job <> Src.Job OR
			  Target.Priority <> Src.Priority OR
			  Target.Dataset <> Src.Dataset OR
			  Target.Experiment <> Src.Experiment OR
			  Target.Campaign <> Src.Campaign OR
			  Target.DatasetID <> Src.DatasetID OR
			  Target.Organism <> Src.Organism OR
			  IsNull(Target.InstrumentName, '') <> IsNull(Src.InstrumentName, '') OR
			  IsNull(Target.InstrumentClass, '') <> IsNull(Src.InstrumentClass, '') OR
			  Target.AnalysisTool <> Src.AnalysisTool OR
			  IsNull(Target.Processor, '') <> IsNull(Src.Processor, '') OR
			  IsNull(Target.Completed, '1/1/1980') <> IsNull(Src.Completed, '1/1/1980') OR
			  Target.ParameterFileName <> Src.ParameterFileName OR
			  IsNull(Target.SettingsFileName, '') <> IsNull(Src.SettingsFileName, '') OR
			  Target.OrganismDBName <> Src.OrganismDBName OR
			  Target.ProteinCollectionList <> Src.ProteinCollectionList OR
			  Target.ProteinOptions <> Src.ProteinOptions OR
			  Target.StoragePathClient <> Src.StoragePathClient OR
			  IsNull(Target.StoragePathServer, '') <> IsNull(Src.StoragePathServer, '') OR
			  IsNull(Target.DatasetFolder, '') <> IsNull(Src.DatasetFolder, '') OR
			  IsNull(Target.ResultsFolder, '') <> IsNull(Src.ResultsFolder, '') OR
			  IsNull(Target.Owner, '') <> IsNull(Src.Owner, '') OR
			  IsNull(Target.Comment, '') <> IsNull(Src.Comment, '') OR
			  IsNull(Target.SeparationSysType, '') <> IsNull(Src.SeparationSysType, '') OR
			  IsNull(Target.ResultType, '') <> IsNull(Src.ResultType, '') OR
			  IsNull(Target.[Dataset Int Std], '') <> IsNull(Src.[Dataset Int Std], '') OR
			  Target.DS_created <> Src.DS_created OR
			  Target.EnzymeID <> Src.EnzymeID OR
			  IsNull(Target.Labelling, '') <> IsNull(Src.Labelling, '') OR
			  Target.[PreDigest Int Std] <> Src.[PreDigest Int Std] OR
			  Target.[PostDigest Int Std] <> Src.[PostDigest Int Std]
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error
		Set @UpdateCount = @myRowcount
		
		If @UpdateCount > 0
		Begin
			If Len(@message) > 0 
				Set @message = @message + '; '
			Set @message = @message + 'Updated ' + convert(varchar(12), @UpdateCount) + ' rows'
		End
		
		Set @CurrentLocation = 'Add new rows to T_DMS_Analysis_Job_Info_Cached'
		--
		INSERT INTO T_DMS_Analysis_Job_Info_Cached
			(Job, Priority, Dataset, Experiment, Campaign, DatasetID, 
			 Organism, InstrumentName, InstrumentClass, AnalysisTool, Processor,
			 Completed, ParameterFileName, SettingsFileName, 
			 OrganismDBName, ProteinCollectionList, ProteinOptions, 
			 StoragePathClient, StoragePathServer, DatasetFolder, 
			 ResultsFolder, Owner, Comment, SeparationSysType, 
			 ResultType, [Dataset Int Std], DS_created, EnzymeID, 
			 Labelling, [PreDigest Int Std], [PostDigest Int Std], Last_Affected)
		SELECT Src.Job, Src.Priority, Src.Dataset, Src.Experiment, Src.Campaign, Src.DatasetID, 
			   Src.Organism, Src.InstrumentName, Src.InstrumentClass, Src.AnalysisTool, Src.Processor,
			   Src.Completed, Src.ParameterFileName, Src.SettingsFileName, 
			   Src.OrganismDBName, Src.ProteinCollectionList, Src.ProteinOptions, 
			   Src.StoragePathClient, Src.StoragePathServer, Src.DatasetFolder, 
			   Src.ResultsFolder, Src.Owner, Src.Comment, Src.SeparationSysType, 
			   Src.ResultType, Src.[Dataset Int Std], Src.DS_created, Src.EnzymeID, 
			   Src.Labelling, Src.[PreDigest Int Std], Src.[PostDigest Int Std], GetDate()
		FROM T_DMS_Analysis_Job_Info_Cached Target RIGHT OUTER JOIN
			 #Tmp_DMS_Analysis_Job_Import_Ex Src ON Target.Job = Src.Job
		WHERE (Target.Job IS NULL)
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error
		Set @InsertCount = @myRowcount
		
		If @InsertCount > 0
		Begin
			If Len(@message) > 0 
				Set @message = @message + '; '
			Set @message = @message + 'Added ' + convert(varchar(12), @InsertCount) + ' new rows'
		End
		
		If Len(@message) > 0 
		Begin	
			Set @message = 'Updated T_DMS_Analysis_Job_Info_Cached using ' + @SourceTable + ': ' + @message
			execute PostLogEntry 'Normal', @message, 'RefreshCachedDMSAnalysisJobInfo'
		End


		Set @CurrentLocation = 'Update stats in T_DMS_Cached_Data_Status'
		--
		-- 
		Exec UpdateDMSCachedDataStatus 'T_DMS_Analysis_Job_Info_Cached', 
											@IncrementRefreshCount = 1, 
											@InsertCountNew = @InsertCount, 
											@UpdateCountNew = @UpdateCount, 
											@DeleteCountNew = @DeleteCount,
											@FullRefreshPerformed = @FullRefreshPerformed, 
											@LastRefreshMinimumID = @JobMinimum

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RefreshCachedDMSAnalysisJobInfo')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
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
