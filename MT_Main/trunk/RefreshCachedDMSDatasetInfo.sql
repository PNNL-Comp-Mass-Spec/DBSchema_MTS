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
**
*****************************************************/
(
	@DatasetIDMinimum int = 0,		-- Set to a positive value to limit the datasets examined; when non-zero, then datasets outside this range are ignored
	@DatasetIDMaximum int = 0,
	@message varchar(255) = '' output
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

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'
	
	Begin Try
		Set @CurrentLocation = 'Validate the inputs'

		Set @DatasetIDMinimum = IsNull(@DatasetIDMinimum, 0)
		Set @DatasetIDMaximum = IsNull(@DatasetIDMaximum, 0)
		
		If @DatasetIDMinimum = 0 AND @DatasetIDMaximum = 0
		Begin
			Set @DatasetIDMinimum = -@MaxInt
			Set @DatasetIDMaximum = @MaxInt
		End
		Else
		If @DatasetIDMinimum > @DatasetIDMaximum
			Set @DatasetIDMaximum = @MaxInt

		Set @CurrentLocation = 'Update Last_Refreshed in T_DMS_Cached_Data_Status'
		-- 
		Exec UpdateDMSCachedDataStatus 'T_DMS_Dataset_Info_Cached', @IncrementRefreshCount = 0


		Set @CurrentLocation = 'Populate a temporary table with the data returned by V_DMS_Dataset_Import_Ex'

		-- Since we need to scan the contents of V_DMS_Dataset_Import_Ex three times, we'll first
		-- populate a local temporary table using its contents
		CREATE TABLE #Tmp_DMS_Dataset_Import_Ex (
			Dataset varchar(128) NOT NULL,
			Experiment varchar(128) NOT NULL,
			Organism varchar(128) NOT NULL,
			Instrument varchar(64) NULL,
			[Separation Type] varchar(64) NULL,
			[LC Column] varchar(128) NOT NULL,
			[Wellplate Number] varchar(64) NULL,
			[Well Number] varchar(64) NULL,
			[Dataset Int Std] varchar(64) NOT NULL,
			Type varchar(64) NOT NULL,
			Operator varchar(255) NOT NULL,
			Comment varchar(500) NULL,
			Rating varchar(64) NOT NULL,
			Request int NULL,
			State varchar(64) NOT NULL,
			Created datetime NOT NULL,
			[Folder Name] varchar(128) NULL,
			[Dataset Folder Path] varchar(1024) NULL,
			[Storage Folder] varchar(256) NOT NULL,
			Storage varchar(1024) NULL,
			[Compressed State] smallint NULL,
			[Compressed Date] datetime NULL,
			ID int NOT NULL,
			[Acquisition Start] datetime NULL,
			[Acquisition End] datetime NULL,
			[Scan Count] int NULL,
			[PreDigest Int Std] varchar(64) NOT NULL,
			[PostDigest Int Std] varchar(64) NOT NULL
		)
		
		-- Create a clustered index on DatasetID
		CREATE CLUSTERED INDEX #IX_Tmp_DMS_Dataset_Import_Ex ON #Tmp_DMS_Dataset_Import_Ex (ID)
		
		-- Populate #Tmp_DMS_Dataset_Import_Ex
		INSERT INTO #Tmp_DMS_Dataset_Import_Ex (
			Dataset, Experiment, Organism, Instrument, 
			[Separation Type], [LC Column], [Wellplate Number], 
			[Well Number], [Dataset Int Std], Type, Operator, Comment, 
			Rating, Request, State, Created, [Folder Name], 
			[Dataset Folder Path], [Storage Folder], Storage, 
			[Compressed State], [Compressed Date], ID, 
			[Acquisition Start], [Acquisition End], [Scan Count], 
			[PreDigest Int Std], [PostDigest Int Std])
		SELECT Dataset, Experiment, Organism, Instrument, 
			   [Separation Type], [LC Column], [Wellplate Number], 
			   [Well Number], [Dataset Int Std], Type, Operator, Comment, 
			   Rating, Request, State, Created, [Folder Name], 
			   [Dataset Folder Path], [Storage Folder], Storage, 
			   [Compressed State], [Compressed Date], ID, 
			   [Acquisition Start], [Acquisition End], [Scan Count], 
			   [PreDigest Int Std], [PostDigest Int Std]
		FROM V_DMS_Dataset_Import_Ex
		WHERE ID >= @DatasetIDMinimum AND ID <= @DatasetIDMaximum
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error
		
		
		Set @CurrentLocation = 'Delete extra rows in T_DMS_Dataset_Info_Cached'
		-- 
		DELETE T_DMS_Dataset_Info_Cached 
		FROM T_DMS_Dataset_Info_Cached Target LEFT OUTER JOIN
			 #Tmp_DMS_Dataset_Import_Ex Src ON Target.ID = Src.ID
		WHERE (Src.ID IS NULL) AND
			  Target.ID >= @DatasetIDMinimum AND Target.ID <= @DatasetIDMaximum
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error
		Set @DeleteCount = @myRowCount
		
		If @DeleteCount > 0
			Set @message = 'Deleted ' + convert(varchar(12), @DeleteCount) + ' extra rows'
			
		Set @CurrentLocation = 'Update existing rows in T_DMS_Dataset_Info_Cached'
		--
		UPDATE T_DMS_Dataset_Info_Cached
		SET Dataset = Src.Dataset,
			Experiment = Src.Experiment,
			Organism = Src.Organism,
			Instrument = Src.Instrument,
			[Separation Type] = Src.[Separation Type],
			[LC Column] = Src.[LC Column],
			[Wellplate Number] = Src.[Wellplate Number],
			[Well Number] = Src.[Well Number],
			[Dataset Int Std] = Src.[Dataset Int Std],
			Type = Src.Type,
			Operator = Src.Operator,
			Comment = Src.Comment,
			Rating = Src.Rating,
			Request = Src.Request,
			State = Src.State,
			Created = Src.Created,
			[Folder Name] = Src.[Folder Name],
			[Dataset Folder Path] = Src.[Dataset Folder Path],
			[Storage Folder] = Src.[Storage Folder],
			Storage = Src.Storage,
			[Compressed State] = Src.[Compressed State],
			[Compressed Date] = Src.[Compressed Date],
			ID = Src.ID,
			[Acquisition Start] = Src.[Acquisition Start],
			[Acquisition End] = Src.[Acquisition End],
			[Scan Count] = Src.[Scan Count],
			[PreDigest Int Std] = Src.[PreDigest Int Std],
			[PostDigest Int Std] = Src.[PostDigest Int Std],
			Last_Affected = GetDate()
		FROM T_DMS_Dataset_Info_Cached Target INNER JOIN
			 #Tmp_DMS_Dataset_Import_Ex Src ON Target.ID = Src.ID
		WHERE   Target.Dataset <> Src.Dataset OR
				Target.Experiment <> Src.Experiment OR
				Target.Organism <> Src.Organism OR 
				IsNull(Target.Instrument, '') <> IsNull(Src.Instrument, '') OR 
				IsNull(Target.[Separation Type], '') <> IsNull(Src.[Separation Type], '') OR 
				Target.[LC Column] <> Src.[LC Column] OR
				IsNull(Target.[Wellplate Number], '') <> IsNull(Src.[Wellplate Number], '') OR 
				IsNull(Target.[Well Number], '') <> IsNull(Src.[Well Number], '') OR 
				Target.[Dataset Int Std] <> Src.[Dataset Int Std] OR
				IsNull(Target.Type, '') <> IsNull(Src.Type, '') OR 
				Target.Operator <> Src.Operator OR 
				IsNull(Target.Comment, '') <> IsNull(Src.Comment, '') OR 
				Target.Rating <> Src.Rating OR 
				IsNull(Target.Rating, '') <> IsNull(Src.Rating, '') OR 
				IsNull(Target.Request, -1) <> IsNull(Src.Request, -1) OR 
				Target.State <> Src.State OR 
				Target.Created <> Src.Created OR 
				IsNull(Target.[Folder Name], '') <> IsNull(Src.[Folder Name], '') OR 
				IsNull(Target.[Dataset Folder Path], '') <> IsNull(Src.[Dataset Folder Path], '') OR 
				IsNull(Target.[Storage Folder], '') <> IsNull(Src.[Storage Folder], '') OR 
				IsNull(Target.Storage, '') <> IsNull(Src.Storage, '') OR 
				IsNull(Target.[Compressed State], -1) <> IsNull(Src.[Compressed State], -1) OR 
				IsNull(Target.[Compressed Date], '') <> IsNull(Src.[Compressed Date], '') OR 
				IsNull(Target.[Acquisition Start], '') <> IsNull(Src.[Acquisition Start], '') OR 
				IsNull(Target.[Acquisition End], '') <> IsNull(Src.[Acquisition End], '') OR 
				IsNull(Target.[Scan Count], -1) <> IsNull(Src.[Scan Count], -1) OR 
				IsNull(Target.[PreDigest Int Std], '') <> IsNull(Src.[PreDigest Int Std], '') OR 
				IsNull(Target.[PostDigest Int Std], '') <> IsNull(Src.[PostDigest Int Std], '')
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error
		Set @UpdateCount = @myRowcount
		
		If @UpdateCount > 0
		Begin
			If Len(@message) > 0 
				Set @message = @message + '; '
			Set @message = @message + 'Updated ' + convert(varchar(12), @UpdateCount) + ' rows'
		End
		
		Set @CurrentLocation = 'Add new rows to T_DMS_Dataset_Info_Cached'
		--
		INSERT INTO T_DMS_Dataset_Info_Cached
			(Dataset, Experiment, Organism, Instrument, 
			 [Separation Type], [LC Column], [Wellplate Number], 
			 [Well Number], [Dataset Int Std], Type, Operator, Comment, 
			 Rating, Request, State, Created, [Folder Name], 
			 [Dataset Folder Path], [Storage Folder], Storage, 
			 [Compressed State], [Compressed Date], ID, 
			 [Acquisition Start], [Acquisition End], [Scan Count], 
			 [PreDigest Int Std], [PostDigest Int Std], Last_Affected)
		SELECT Src.Dataset, Src.Experiment, Src.Organism, Src.Instrument,
			   Src.[Separation Type], Src.[LC Column], Src.[Wellplate Number],
			   Src.[Well Number], Src.[Dataset Int Std], Src.Type, Src.Operator, Src.Comment,
			   Src.Rating, Src.Request, Src.State, Src.Created, Src.[Folder Name],
			   Src.[Dataset Folder Path], Src.[Storage Folder], Src.Storage,
			   Src.[Compressed State], Src.[Compressed Date], Src.ID,
			   Src.[Acquisition Start], Src.[Acquisition End], Src.[Scan Count], 
			   Src.[PreDigest Int Std], Src.[PostDigest Int Std], GetDate()
		FROM T_DMS_Dataset_Info_Cached Target RIGHT OUTER JOIN
			 #Tmp_DMS_Dataset_Import_Ex Src ON Target.ID = Src.ID
		WHERE (Target.ID IS NULL)
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
			Set @message = 'Updated T_DMS_Dataset_Info_Cached: ' + @message
			execute PostLogEntry 'Normal', @message, 'RefreshCachedDMSDatasetInfo'
		End


		Set @CurrentLocation = 'Update stats in T_DMS_Cached_Data_Status'
		-- 
		Exec UpdateDMSCachedDataStatus 'T_DMS_Dataset_Info_Cached', 
											@IncrementRefreshCount = 1, 
											@InsertCountNew = @InsertCount, 
											@UpdateCountNew = @UpdateCount, 
											@DeleteCountNew = @DeleteCount
		
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
