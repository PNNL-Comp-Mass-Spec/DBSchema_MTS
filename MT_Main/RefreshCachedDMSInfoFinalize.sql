/****** Object:  StoredProcedure [dbo].[RefreshCachedDMSInfoFinalize] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.RefreshCachedDMSInfoFinalize
/****************************************************
**
**	Desc: 
**		Summarizes data in #Tmp_UpdateSummary after a Merge operation
**		Updates T_DMS_Cached_Data_Status with the new stats
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	07/30/2010 mem - Initial Version
**    
*****************************************************/
(
	@CallingProcedureName varchar(128),
	@SourceTable varchar(256),				-- Optional: if Blank, then will not be included in the log message
	@TargetTableName varchar(256),
	@IncrementRefreshCount tinyint = 1, 
	@FullRefreshPerformed tinyint = 1,
	@LastRefreshMinimumID int = 0

)
As
	Set NoCount On

	Declare @DeleteCount int
	Declare @UpdateCount int
	Declare @InsertCount int

	Declare @message varchar(512)
	Declare @prefix varchar(255)
	
	set @message = ''
	
	SELECT @InsertCount = COUNT(*)
	FROM #Tmp_UpdateSummary
	WHERE UpdateAction = 'INSERT'

	SELECT @UpdateCount = COUNT(*)
	FROM #Tmp_UpdateSummary
	WHERE UpdateAction = 'UPDATE'

	SELECT @DeleteCount = COUNT(*)
	FROM #Tmp_UpdateSummary
	WHERE UpdateAction = 'DELETE'

	If @DeleteCount > 0
		Set @message = 'Deleted ' + convert(varchar(12), @DeleteCount) + ' extra rows'
			
	If @UpdateCount > 0
	Begin
		If Len(@message) > 0 
			Set @message = @message + '; '
		Set @message = @message + 'Updated ' + convert(varchar(12), @UpdateCount) + ' rows'
	End
		
	If @InsertCount > 0
	Begin
		If Len(@message) > 0 
			Set @message = @message + '; '
		Set @message = @message + 'Added ' + convert(varchar(12), @InsertCount) + ' new rows'
	End
	
	If Len(@message) > 0 
	Begin	
		Set @prefix = 'Updated ' + @TargetTableName
		
		If Len(IsNull(@SourceTable, '')) > 0
			Set @message = @prefix + ' using ' + @SourceTable + ': ' + @message
		Else
			Set @message = @prefix + ': ' + @message
			
		execute PostLogEntry 'Normal', @message, @CallingProcedureName
	End

	-- 
	Exec UpdateDMSCachedDataStatus @TargetTableName, 
										@IncrementRefreshCount = @IncrementRefreshCount, 
										@InsertCountNew = @InsertCount, 
										@UpdateCountNew = @UpdateCount, 
										@DeleteCountNew = @DeleteCount,
										@FullRefreshPerformed = @FullRefreshPerformed, 
										@LastRefreshMinimumID = @LastRefreshMinimumID

			
Done:
	Return 0


GO
GRANT VIEW DEFINITION ON [dbo].[RefreshCachedDMSInfoFinalize] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RefreshCachedDMSInfoFinalize] TO [MTS_DB_Lite] AS [dbo]
GO
