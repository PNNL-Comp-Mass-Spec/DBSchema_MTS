/****** Object:  StoredProcedure [dbo].[RefreshCachedDMSInfoIfRequired] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.RefreshCachedDMSInfoIfRequired
/****************************************************
**
**	Desc: 
**		Calls the various RefreshCachedDMS procedures if the
**		Last_Refreshed date in T_DMS_Cached_Data_Status is over
**		@UpdateInterval hours before the present
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	05/09/2007 - See Ticket:422
**    
*****************************************************/
(
	@UpdateInterval real = 1,			-- Minimum interval in hours to limit update frequency; Set to 0 to force update now
	@InfoOnly tinyint = 0,
 	@message varchar(255) = '' output
)
As
	Set NoCount On

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	set @message = ''

	Declare @CurrentTime datetime
	Set @CurrentTime = GetDate()

	Declare @LastRefreshed datetime
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'
	
	Begin Try
		Set @CurrentLocation = 'Validate the inputs'
		--
		Set @UpdateInterval = IsNull(@UpdateInterval, 1)
		Set @message = ''
		
		
		Set @CurrentLocation = 'Check refresh time for T_DMS_Analysis_Job_Info_Cached'
		--
		Set @LastRefreshed = '1/1/2000'
		SELECT @LastRefreshed = Last_Refreshed
		FROM T_DMS_Cached_Data_Status
		WHERE Table_Name = 'T_DMS_Analysis_Job_Info_Cached'
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error
		
		If DateDiff(minute, @LastRefreshed, @CurrentTime) / 60.0 >= @UpdateInterval
		Begin
			If @InfoOnly = 0
				Exec @myError = RefreshCachedDMSAnalysisJobInfo @message = @message Output
			Else
				Print 'Need to call RefreshCachedDMSAnalysisJobInfo since last refreshed ' + Convert(varchar(32), @LastRefreshed)
		End


		Set @CurrentLocation = 'Check refresh time for T_DMS_Dataset_Info_Cached'
		--
		Set @LastRefreshed = '1/1/2000'
		SELECT @LastRefreshed = Last_Refreshed
		FROM T_DMS_Cached_Data_Status
		WHERE Table_Name = 'T_DMS_Dataset_Info_Cached'
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error
		
		If DateDiff(minute, @LastRefreshed, @CurrentTime) / 60.0 >= @UpdateInterval
		Begin
			If @InfoOnly = 0
				Exec @myError = RefreshCachedDMSDatasetInfo @message = @message Output
			Else
				Print 'Need to call RefreshCachedDMSDatasetInfo since last refreshed ' + Convert(varchar(32), @LastRefreshed)
		End
		
		
		Set @CurrentLocation = 'Check refresh time for T_DMS_Mass_Correction_Factors_Cached'
		--
		Set @LastRefreshed = '1/1/2000'
		SELECT @LastRefreshed = Last_Refreshed
		FROM T_DMS_Cached_Data_Status
		WHERE Table_Name = 'T_DMS_Mass_Correction_Factors_Cached'
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error
		
		If DateDiff(minute, @LastRefreshed, @CurrentTime) / 60.0 >= @UpdateInterval
		Begin
			If @InfoOnly = 0
				Exec @myError = RefreshCachedDMSMassCorrectionFactors @message = @message Output
			Else
				Print 'Need to call RefreshCachedDMSMassCorrectionFactors since last refreshed ' + Convert(varchar(32), @LastRefreshed)
		End
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RefreshCachedDMSInfoIfRequired')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done		
	End Catch
			
Done:
	Return @myError


GO
