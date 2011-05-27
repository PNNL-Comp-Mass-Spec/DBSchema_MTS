/****** Object:  StoredProcedure [dbo].[RefreshCachedDMSDatasetInfo] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.RefreshCachedDMSDatasetInfo
/****************************************************
**
**	Desc:	Updates the data in T_DMS_Dataset_Info_Cached using DMS
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	05/09/2007 - See Ticket:422
**			08/07/2008 mem - Added parameter @SourceMTSServer; if provided, then contacts that server rather than contacting DMS.
**			09/18/2008 mem - Now passing @FullRefreshPerformed and @LastRefreshMinimumID to UpdateDMSCachedDataStatus
**			08/02/2010 mem - Updated to use a single-step MERGE statement instead of three separate Delete, Update, and Insert statements
**						   - Added parameter @UpdateSourceMTSServer
**			12/13/2010 mem - Fixed the table name being sent to RefreshCachedDMSInfoFinalize and PostLogEntry
**			03/03/2011 mem - Now populating [File Size MB]
**
*****************************************************/
(
	@DatasetIDMinimum int = 0,		-- Set to a positive value to limit the datasets examined; when non-zero, then datasets outside this range are ignored
	@DatasetIDMaximum int = 0,
	@SourceMTSServer varchar(128) = 'porky',	-- MTS Server to look at to get this information from (in the MT_Main database); if blank, then uses V_DMS_Dataset_Import_Ex
	@UpdateSourceMTSServer tinyint = 0,			-- If 1, then first calls RefreshCachedDMSDatasetInfo on the source MTS server; only valid if @SourceMTSServer is not blank
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
	
	---------------------------------------------------
	-- Create the temporary table that will be used to
	-- track the number of inserts, updates, and deletes 
	-- performed by the MERGE statement
	---------------------------------------------------
	
	CREATE TABLE #Tmp_UpdateSummary (
		UpdateAction varchar(32)
	)
		
	Begin Try
		Set @CurrentLocation = 'Validate the inputs'

		-- Validate the inputs
		Set @DatasetIDMinimum = IsNull(@DatasetIDMinimum, 0)
		Set @DatasetIDMaximum = IsNull(@DatasetIDMaximum, 0)
		Set @SourceMTSServer = IsNull(@SourceMTSServer, '')
		Set @UpdateSourceMTSServer = IsNull(@UpdateSourceMTSServer, 0)
		Set @previewSql = IsNull(@previewSql, 0)

		If @DatasetIDMinimum = 0 AND @DatasetIDMaximum = 0
		Begin
			Set @FullRefreshPerformed = 1
			Set @DatasetIDMinimum = -@MaxInt
			Set @DatasetIDMaximum = @MaxInt
		End
		Else
		Begin
			Set @FullRefreshPerformed = 0
			If @DatasetIDMinimum > @DatasetIDMaximum
				Set @DatasetIDMaximum = @MaxInt
		End

		-- Source server cannot be this server; if they match, set @SourceMTSServer to ''
		If @SourceMTSServer = @@ServerName
			Set @SourceMTSServer = ''

		If @SourceMTSServer <> '' And @UpdateSourceMTSServer <> 0
		Begin
			Set @CurrentLocation = 'Call RefreshCachedDMSDatasetInfo on server ' + @SourceMTSServer

			-- Call RefreshCachedDMSDatasetInfo on server @SourceMTSServer
			Set @S = 'exec ' + @SourceMTSServer + '.MT_Main.dbo.RefreshCachedDMSDatasetInfo ' + Convert(varchar(12), @DatasetIDMinimum) + ', ' +  + Convert(varchar(12), @DatasetIDMaximum)
			
			If @previewSql <> 0
				Print @S
			Else
				Exec (@S)

		End
				
		If @SourceMTSServer <> ''
			Set @SourceTable = @SourceMTSServer + '.MT_Main.dbo.T_DMS_Dataset_Info_Cached'
		Else
			Set @SourceTable = 'V_DMS_Dataset_Import_Ex'
		
				
		Set @CurrentLocation = 'Update Last_Refreshed in T_DMS_Cached_Data_Status'
		-- 
		Exec UpdateDMSCachedDataStatus 'T_DMS_Dataset_Info_Cached', @IncrementRefreshCount = 0, @FullRefreshPerformed = @FullRefreshPerformed, @LastRefreshMinimumID = @DatasetIDMinimum


		Set @CurrentLocation = 'Merge data into T_DMS_Dataset_Info_Cached'

		-- Use a MERGE Statement to synchronize T_DMS_Dataset_Info_Cached with @SourceTable
		--
		Set @S = ''
		Set @S = @S + ' MERGE T_DMS_Dataset_Info_Cached AS target'
		Set @S = @S + ' USING (SELECT   Dataset, Experiment, Organism, Instrument, '
		Set @S = @S +                 ' [Separation Type], [LC Column], [Wellplate Number], '
		Set @S = @S +                 ' [Well Number], [Dataset Int Std], Type, Operator, Comment, '
		Set @S = @S +                 ' Rating, Request, State, Created, [Folder Name], '
		Set @S = @S +                 ' [Dataset Folder Path], [Storage Folder], Storage, ' 
		Set @S = @S +                 ' [Compressed State], [Compressed Date], ID, '
		Set @S = @S +                 ' [Acquisition Start], [Acquisition End], [Scan Count], [File Size MB],'
		Set @S = @S +                 ' [PreDigest Int Std], [PostDigest Int Std]'
		Set @S = @S + '          FROM ' + @SourceTable
		Set @S = @S + '          WHERE ID >= ' + Convert(varchar(12), @DatasetIDMinimum) + ' AND ID <= ' + Convert(varchar(12), @DatasetIDMaximum)
		Set @S = @S + '	) AS Source (	Dataset, Experiment, Organism, Instrument, '
		Set @S = @S +                 ' [Separation Type], [LC Column], [Wellplate Number], '
		Set @S = @S +                 ' [Well Number], [Dataset Int Std], Type, Operator, Comment, '
		Set @S = @S +                 ' Rating, Request, State, Created, [Folder Name], '
		Set @S = @S +                 ' [Dataset Folder Path], [Storage Folder], Storage, '
		Set @S = @S +                 ' [Compressed State], [Compressed Date], ID, '
		Set @S = @S +                 ' [Acquisition Start], [Acquisition End], [Scan Count], [File Size MB],'
		Set @S = @S +                 ' [PreDigest Int Std], [PostDigest Int Std])'
		Set @S = @S + ' ON (target.ID = source.ID)'
		Set @S = @S + ' WHEN Matched AND ( 	Target.Dataset <> source.Dataset OR'
		Set @S = @S +                     ' Target.Experiment <> source.Experiment OR'
		Set @S = @S +                     ' Target.Organism <> source.Organism OR '
		Set @S = @S +                     ' IsNull(Target.Instrument, '''') <> IsNull(source.Instrument, '''') OR '
		Set @S = @S +                     ' IsNull(Target.[Separation Type], '''') <> IsNull(source.[Separation Type], '''') OR '
		Set @S = @S +                     ' Target.[LC Column] <> source.[LC Column] OR'
		Set @S = @S +                     ' IsNull(Target.[Wellplate Number], '''') <> IsNull(source.[Wellplate Number], '''') OR '
		Set @S = @S +                     ' IsNull(Target.[Well Number], '''') <> IsNull(source.[Well Number], '''') OR '
		Set @S = @S +                     ' Target.[Dataset Int Std] <> source.[Dataset Int Std] OR'
		Set @S = @S +                     ' IsNull(Target.Type, '''') <> IsNull(source.Type, '''') OR '
		Set @S = @S +                     ' Target.Operator <> source.Operator OR '
		Set @S = @S +                     ' IsNull(Target.Comment, '''') <> IsNull(source.Comment, '''') OR '
		Set @S = @S +                     ' Target.Rating <> source.Rating OR '
		Set @S = @S +                     ' IsNull(Target.Rating, '''') <> IsNull(source.Rating, '''') OR '
		Set @S = @S +                     ' IsNull(Target.Request, -1) <> IsNull(source.Request, -1) OR '
		Set @S = @S +                     ' Target.State <> source.State OR '
		Set @S = @S +                     ' Target.Created <> source.Created OR '
		Set @S = @S +                     ' IsNull(Target.[Folder Name], '''') <> IsNull(source.[Folder Name], '''') OR '
		Set @S = @S +                     ' IsNull(Target.[Dataset Folder Path], '''') <> IsNull(source.[Dataset Folder Path], '''') OR '
		Set @S = @S +                     ' IsNull(Target.[Storage Folder], '''') <> IsNull(source.[Storage Folder], '''') OR '
		Set @S = @S +  ' IsNull(Target.Storage, '''') <> IsNull(source.Storage, '''') OR '
		Set @S = @S +   ' IsNull(Target.[Compressed State], -1) <> IsNull(source.[Compressed State], -1) OR '
		Set @S = @S +                     ' IsNull(Target.[Compressed Date], '''') <> IsNull(source.[Compressed Date], '''') OR '
		Set @S = @S +                     ' IsNull(Target.[Acquisition Start], '''') <> IsNull(source.[Acquisition Start], '''') OR '
		Set @S = @S +                     ' IsNull(Target.[Acquisition End], '''') <> IsNull(source.[Acquisition End], '''') OR '
		Set @S = @S +                     ' IsNull(Target.[Scan Count], -1) <> IsNull(source.[Scan Count], -1) OR '
		Set @S = @S +                     ' IsNull(Target.[File Size MB], -1) <> IsNull(source.[File Size MB], -1) OR '		
		Set @S = @S +                     ' IsNull(Target.[PreDigest Int Std], '''') <> IsNull(source.[PreDigest Int Std], '''') OR '
		Set @S = @S +                     ' IsNull(Target.[PostDigest Int Std], '''') <> IsNull(source.[PostDigest Int Std], '''') ) THEN '
		Set @S = @S + '	UPDATE set Dataset = source.Dataset,'
		Set @S = @S +          ' Experiment = source.Experiment,'
		Set @S = @S +          ' Organism = source.Organism,'
		Set @S = @S +          ' Instrument = source.Instrument,'
		Set @S = @S +          ' [Separation Type] = source.[Separation Type],'
		Set @S = @S +          ' [LC Column] = source.[LC Column],'
		Set @S = @S +          ' [Wellplate Number] = source.[Wellplate Number],'
		Set @S = @S +          ' [Well Number] = source.[Well Number],'
		Set @S = @S +          ' [Dataset Int Std] = source.[Dataset Int Std],'
		Set @S = @S +          ' Type = source.Type,'
		Set @S = @S +          ' Operator = source.Operator,'
		Set @S = @S +          ' Comment = source.Comment,'
		Set @S = @S +          ' Rating = source.Rating,'
		Set @S = @S +          ' Request = source.Request,'
		Set @S = @S +          ' State = source.State,'
		Set @S = @S +          ' Created = source.Created,'
		Set @S = @S +          ' [Folder Name] = source.[Folder Name],'
		Set @S = @S +          ' [Dataset Folder Path] = source.[Dataset Folder Path],'
		Set @S = @S +          ' [Storage Folder] = source.[Storage Folder],'
		Set @S = @S +          ' Storage = source.Storage,'
		Set @S = @S +          ' [Compressed State] = source.[Compressed State],'
		Set @S = @S +          ' [Compressed Date] = source.[Compressed Date],'
		Set @S = @S +          ' ID = source.ID,'
		Set @S = @S +          ' [Acquisition Start] = source.[Acquisition Start],'
		Set @S = @S +          ' [Acquisition End] = source.[Acquisition End],'
		Set @S = @S +          ' [Scan Count] = source.[Scan Count],'
		Set @S = @S +          ' [File Size MB] = source.[File Size MB],'		
		Set @S = @S +          ' [PreDigest Int Std] = source.[PreDigest Int Std],'
		Set @S = @S +          ' [PostDigest Int Std] = source.[PostDigest Int Std],'
		Set @S = @S +          ' Last_Affected = GetDate()'
		Set @S = @S + ' WHEN Not Matched THEN'
		Set @S = @S + '	INSERT (Dataset, Experiment, Organism, Instrument, '
		Set @S = @S +         ' [Separation Type], [LC Column], [Wellplate Number], '
		Set @S = @S +         ' [Well Number], [Dataset Int Std], Type, Operator, Comment, '
		Set @S = @S +         ' Rating, Request, State, Created, [Folder Name], '
		Set @S = @S +         ' [Dataset Folder Path], [Storage Folder], Storage,' 
		Set @S = @S +         ' [Compressed State], [Compressed Date], ID, '
		Set @S = @S +         ' [Acquisition Start], [Acquisition End], [Scan Count], [File Size MB],'
		Set @S = @S +         ' [PreDigest Int Std], [PostDigest Int Std], Last_Affected)'
		Set @S = @S + '	VALUES ( source.Dataset, source.Experiment, source.Organism, source.Instrument,'
		Set @S = @S +          ' source.[Separation Type], source.[LC Column], source.[Wellplate Number],'
		Set @S = @S +          ' source.[Well Number], source.[Dataset Int Std], source.Type, source.Operator, source.Comment,'
		Set @S = @S +          ' source.Rating, source.Request, source.State, source.Created, source.[Folder Name],'
		Set @S = @S +          ' source.[Dataset Folder Path], source.[Storage Folder], source.Storage,'
		Set @S = @S +          ' source.[Compressed State], source.[Compressed Date], source.ID,'
		Set @S = @S +          ' source.[Acquisition Start], source.[Acquisition End], source.[Scan Count], [File Size MB],'
		Set @S = @S +          ' source.[PreDigest Int Std], source.[PostDigest Int Std], GetDate())'
		Set @S = @S + ' WHEN NOT MATCHED BY SOURCE AND '
		Set @S = @S + '    Target.ID >= ' + Convert(varchar(12), @DatasetIDMinimum) + ' AND Target.ID <= ' + Convert(varchar(12), @DatasetIDMaximum) + ' THEN'
		Set @S = @S + '	DELETE'
		Set @S = @S + ' OUTPUT $action INTO #Tmp_UpdateSummary'
		Set @S = @S + ';'

		if @PreviewSql <> 0
			Print @S
		Else
			Exec (@S)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myError <> 0
		Begin
			set @message = 'Error merging ' + @SourceTable + ' with T_DMS_Dataset_Info_Cached (ErrorID = ' + Convert(varchar(12), @myError) + ')'
			execute PostLogEntry 'Error', @message, 'RefreshCachedDMSDatasetInfo'
		End
		Else
		Begin

			-- Update the stats in T_DMS_Cached_Data_Status
			exec RefreshCachedDMSInfoFinalize 'RefreshCachedDMSDatasetInfo', @SourceTable, 'T_DMS_Dataset_Info_Cached',
												@IncrementRefreshCount = 1, 
												@FullRefreshPerformed = @FullRefreshPerformed, 
												@LastRefreshMinimumID = @DatasetIDMinimum
		End

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RefreshCachedDMSDatasetInfo')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done		
	End Catch
			
Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[RefreshCachedDMSDatasetInfo] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RefreshCachedDMSDatasetInfo] TO [MTS_DB_Lite] AS [dbo]
GO
