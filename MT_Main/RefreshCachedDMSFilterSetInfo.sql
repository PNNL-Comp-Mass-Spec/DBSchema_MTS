/****** Object:  StoredProcedure [dbo].[RefreshCachedDMSFilterSetInfo] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE RefreshCachedDMSFilterSetInfo
/****************************************************
**
**	Desc:	Updates the data in T_DMS_Filter_Set_Overview_Cached, 
**			T_DMS_Filter_Set_Criteria_Names_Cached, and T_DMS_Filter_Set_Details_Cached using DMS
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	08/02/2010 mem - Initial Version
**			10/03/2011 mem - Now populating T_DMS_Filter_Set_Criteria_Names_Cached
**
*****************************************************/
(
	@message varchar(255) = '' output
)
AS

	Set NoCount On

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	set @message = ''

	Declare @DeleteCount int
	Declare @UpdateCount int
	Declare @InsertCount int

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

		Set @CurrentLocation = 'Update Last_Refreshed in T_DMS_Cached_Data_Status'
		-- 
		Exec UpdateDMSCachedDataStatus 'T_DMS_Filter_Set_Overview_Cached', @IncrementRefreshCount = 0, @FullRefreshPerformed = 1, @LastRefreshMinimumID = 0

		Set @CurrentLocation = 'Merge data into T_DMS_Filter_Set_Overview_Cached'

		-- Use a MERGE Statement to synchronize T_DMS_Filter_Set_Overview_Cached with V_DMS_Filter_Set_Overview_Import
		--
		MERGE T_DMS_Filter_Set_Overview_Cached AS target
		USING (SELECT Filter_Type_ID,
					Filter_Type_Name,
					Filter_Set_ID,
					Filter_Set_Name,
					Filter_Set_Description
			FROM V_DMS_Filter_Set_Overview_Import
			) AS Source ( Filter_Type_ID,
						Filter_Type_Name,
						Filter_Set_ID,
						Filter_Set_Name,
						Filter_Set_Description)
		ON (target.Filter_Set_ID = source.Filter_Set_ID)
		WHEN Matched AND (target.Filter_Type_ID <> source.Filter_Type_ID OR
						target.Filter_Type_Name <> source.Filter_Type_Name  OR
						target.Filter_Set_Name <> source.Filter_Set_Name  OR
						target.Filter_Set_Description <> source.Filter_Set_Description 
						) THEN 
			UPDATE set Filter_Type_ID = source.Filter_Type_ID,
					Filter_Type_Name = source.Filter_Type_Name,
					Filter_Set_Name = source.Filter_Set_Name,
					Filter_Set_Description = source.Filter_Set_Description,
					Last_Affected = GetDate()
		WHEN Not Matched THEN
			INSERT (Filter_Set_ID,
					Filter_Type_ID,
					Filter_Type_Name,
					Filter_Set_Name,
					Filter_Set_Description, 
					Last_Affected)
			VALUES (source.Filter_Set_ID,
					source.Filter_Type_ID,
					source.Filter_Type_Name,
					source.Filter_Set_Name,
					source.Filter_Set_Description,
					GetDate())
		WHEN NOT MATCHED BY SOURCE THEN 
			DELETE
		OUTPUT $action INTO #Tmp_UpdateSummary
		;
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		if @myError <> 0
		begin
			set @message = 'Error merging V_DMS_Filter_Set_Overview_Import with T_DMS_Filter_Set_Overview_Cached (ErrorID = ' + Convert(varchar(12), @myError) + ')'
			execute PostLogEntry 'Error', @message, 'RefreshCachedDMSFilterSetInfo'
		end

		-- Update the stats in T_DMS_Cached_Data_Status
		exec RefreshCachedDMSInfoFinalize 'RefreshCachedDMSFilterSetInfo', '', 'T_DMS_Filter_Set_Overview_Cached'
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RefreshCachedDMSFilterSetInfo')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done		
	End Catch
	
	 
	 
	Begin Try
		truncate table #Tmp_UpdateSummary

		Set @CurrentLocation = 'Update Last_Refreshed in T_DMS_Cached_Data_Status for T_DMS_Filter_Set_Criteria_Names_Cached'
		-- 
		Exec UpdateDMSCachedDataStatus 'T_DMS_Filter_Set_Criteria_Names_Cached', @IncrementRefreshCount = 0, @FullRefreshPerformed = 1, @LastRefreshMinimumID = 0

		Set @CurrentLocation = 'Merge data into T_DMS_Filter_Set_Criteria_Names_Cached'

		-- Use a MERGE Statement to synchronize T_DMS_Filter_Set_Criteria_Names_Cached with filter set criteria names in V_DMS_Filter_Sets_Import
		--
		MERGE T_DMS_Filter_Set_Criteria_Names_Cached AS target
		USING (SELECT DISTINCT Criterion_ID, Criterion_Name
			FROM V_DMS_Filter_Sets_Import
			) AS Source ( Criterion_ID, Criterion_Name)
		ON (target.Criterion_ID = source.Criterion_ID)
		WHEN Matched AND (target.Criterion_Name <> source.Criterion_Name) THEN 
			UPDATE set Criterion_Name = source.Criterion_Name,
					   Last_Affected = GetDate()
		WHEN Not Matched THEN
			INSERT (Criterion_ID, Criterion_Name, Last_Affected)
			VALUES (source.Criterion_ID, source.Criterion_Name, GetDate())
		WHEN NOT MATCHED BY SOURCE THEN 
			DELETE
		OUTPUT $action INTO #Tmp_UpdateSummary
		;
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		if @myError <> 0
		begin
			set @message = 'Error merging V_DMS_Filter_Sets_Import with T_DMS_Filter_Set_Criteria_Names_Cached (ErrorID = ' + Convert(varchar(12), @myError) + ')'
			execute PostLogEntry 'Error', @message, 'RefreshCachedDMSFilterSetInfo'
			goto Done
		end

		-- Update the stats in T_DMS_Cached_Data_Status
		exec RefreshCachedDMSInfoFinalize 'RefreshCachedDMSFilterSetInfo', '', 'T_DMS_Filter_Set_Criteria_Names_Cached'
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RefreshCachedDMSFilterSetInfo')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done		
	End Catch
	
	 
	Begin Try
		truncate table #Tmp_UpdateSummary

		Set @CurrentLocation = 'Update Last_Refreshed in T_DMS_Cached_Data_Status for T_DMS_Filter_Set_Details_Cached'
		-- 
		Exec UpdateDMSCachedDataStatus 'T_DMS_Filter_Set_Details_Cached', @IncrementRefreshCount = 0, @FullRefreshPerformed = 1, @LastRefreshMinimumID = 0

		Set @CurrentLocation = 'Merge data into T_DMS_Filter_Set_Details_Cached'

		-- Use a MERGE Statement to synchronize T_DMS_Filter_Set_Details_Cached with V_DMS_Filter_Sets_Import
		--
		MERGE T_DMS_Filter_Set_Details_Cached AS target
		USING (SELECT Filter_Set_Criteria_ID, Filter_Set_ID, Filter_Criteria_Group_ID,
					Criterion_ID, Criterion_Comparison, Criterion_Value
			FROM V_DMS_Filter_Sets_Import
			) AS Source ( Filter_Set_Criteria_ID, Filter_Set_ID, Filter_Criteria_Group_ID,
						Criterion_ID, Criterion_Comparison, Criterion_Value)
		ON (target.Filter_Set_Criteria_ID = source.Filter_Set_Criteria_ID)
		WHEN Matched AND (target.Filter_Set_ID <> source.Filter_Set_ID OR
						target.Filter_Criteria_Group_ID <> source.Filter_Criteria_Group_ID OR
						target.Criterion_ID <> source.Criterion_ID OR 
						target.Criterion_Comparison <> source.Criterion_Comparison OR
						target.Criterion_Value <> source.Criterion_Value
						) THEN 
			UPDATE set Filter_Set_ID = source.Filter_Set_ID,
					Filter_Criteria_Group_ID = source.Filter_Criteria_Group_ID,
					Criterion_ID = source.Criterion_ID,
					Criterion_Comparison = source.Criterion_Comparison,
					Criterion_Value = source.Criterion_Value,
					Last_Affected = GetDate()
		WHEN Not Matched THEN
			INSERT (Filter_Set_Criteria_ID, Filter_Set_ID, Filter_Criteria_Group_ID,
					Criterion_ID, Criterion_Comparison, Criterion_Value,
					Last_Affected)
			VALUES (source.Filter_Set_Criteria_ID, source.Filter_Set_ID, source.Filter_Criteria_Group_ID,
					source.Criterion_ID, source.Criterion_Comparison, source.Criterion_Value,
					GetDate())
		WHEN NOT MATCHED BY SOURCE THEN 
			DELETE
		OUTPUT $action INTO #Tmp_UpdateSummary
		;
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		if @myError <> 0
		begin
			set @message = 'Error merging V_DMS_Filter_Sets_Import with T_DMS_Filter_Set_Details_Cached (ErrorID = ' + Convert(varchar(12), @myError) + ')'
			execute PostLogEntry 'Error', @message, 'RefreshCachedDMSFilterSetInfo'
			goto Done
		end

		-- Update the stats in T_DMS_Cached_Data_Status
		exec RefreshCachedDMSInfoFinalize 'RefreshCachedDMSFilterSetInfo', '', 'T_DMS_Filter_Set_Details_Cached'
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RefreshCachedDMSFilterSetInfo')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done		
	End Catch
			
Done:

	drop table #Tmp_UpdateSummary
	
	Return @myError

GO
GRANT EXECUTE ON [dbo].[RefreshCachedDMSFilterSetInfo] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RefreshCachedDMSFilterSetInfo] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RefreshCachedDMSFilterSetInfo] TO [MTS_DB_Lite] AS [dbo]
GO
