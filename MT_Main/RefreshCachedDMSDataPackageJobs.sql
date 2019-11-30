/****** Object:  StoredProcedure [dbo].[RefreshCachedDMSDataPackageJobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE RefreshCachedDMSDataPackageJobs
/****************************************************
**
**	Desc:	Updates the data in T_DMS_Data_Package_Jobs_Cached using DMS
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	04/27/2016 mem - Initial Version
**
*****************************************************/
(
	@DataPkgIDMinimum int = 0,						-- Set to a positive value to limit the data packages examined
	@message varchar(255) = '' output
)
AS

	Set NoCount On

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Declare @DeleteCount int = 0
	Declare @UpdateCount int = 0
	Declare @InsertCount int = 0

	Declare @FullRefreshPerformed tinyint

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

		-- Validate the inputs
		--
		Set @DataPkgIDMinimum = IsNull(@DataPkgIDMinimum, 0)
		set @message = ''

		If @DataPkgIDMinimum <= 0 
		Begin
			Set @FullRefreshPerformed = 1
			Set @DataPkgIDMinimum = -0
		End
		Else
		Begin
			Set @FullRefreshPerformed = 0
		End
		
		
		Set @CurrentLocation = 'Update Last_Refreshed in T_DMS_Cached_Data_Status'
		-- 
		Exec UpdateDMSCachedDataStatus 'T_DMS_Data_Package_Jobs_Cached', @IncrementRefreshCount = 0, @FullRefreshPerformed = @FullRefreshPerformed, @LastRefreshMinimumID = @DataPkgIDMinimum

		Set @CurrentLocation = 'Merge data into T_DMS_Data_Package_Jobs_Cached'

		-- Use a MERGE Statement to synchronize T_DMS_Data_Package_Jobs_Cached with V_DMS_Data_Package_Jobs_Import
		--
		 
		MERGE dbo.T_DMS_Data_Package_Jobs_Cached AS t
		USING (SELECT Data_Package_ID, Job, Dataset, Tool, Package_Comment, Item_Added 
		       FROM V_DMS_Data_Package_Jobs_Import
		       WHERE Data_Package_ID >= @DataPkgIDMinimum) as s
		ON ( t.Data_Package_ID = s.Data_Package_ID AND t.Job = s.Job)
		WHEN MATCHED AND (
			t.Item_Added <> s.Item_Added OR
			IsNull(t.Dataset, '') <> IsNull(s.Dataset, '') OR
			IsNull(t.Tool, '') <> IsNull(s.Tool, '') OR
			IsNull(t.Package_Comment, '') <> IsNull(s.Package_Comment, '')
			)
		THEN UPDATE SET 
			Dataset = s.Dataset,
			Tool = s.Tool,
			Package_Comment = s.Package_Comment,
			Item_Added = s.Item_Added,
			Last_Affected = GetDate()
		WHEN NOT MATCHED BY TARGET THEN
			INSERT(Data_Package_ID, Job, Dataset, Tool, Package_Comment, Item_Added)
			VALUES(s.Data_Package_ID, s.Job, s.Dataset, s.Tool, s.Package_Comment, s.Item_Added)
		WHEN NOT MATCHED BY SOURCE AND t.Data_Package_ID >= @DataPkgIDMinimum THEN 
			DELETE
		OUTPUT $action INTO #Tmp_UpdateSummary
		;
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		if @myError <> 0
		begin
			set @message = 'Error merging V_DMS_Data_Package_Jobs_Import with T_DMS_Data_Package_Jobs_Cached (ErrorID = ' + Convert(varchar(12), @myError) + ')'
			execute PostLogEntry 'Error', @message, 'RefreshCachedDMSDataPackageJobs'
		end

		-- Update the stats in T_DMS_Cached_Data_Status
		exec RefreshCachedDMSInfoFinalize 'RefreshCachedDMSDataPackageJobs', 'V_DMS_Data_Package_Jobs_Import', 'T_DMS_Data_Package_Jobs_Cached',
												@IncrementRefreshCount = 1, 
												@FullRefreshPerformed = @FullRefreshPerformed, 
												@LastRefreshMinimumID = @DataPkgIDMinimum
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RefreshCachedDMSDataPackageJobs')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList=53,
								@ErrorNum = @myError output, @message = @message output
		Goto Done		
	End Catch
				
Done:

	drop table #Tmp_UpdateSummary
	
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[RefreshCachedDMSDataPackageJobs] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RefreshCachedDMSDataPackageJobs] TO [MTS_DB_Lite] AS [dbo]
GO
