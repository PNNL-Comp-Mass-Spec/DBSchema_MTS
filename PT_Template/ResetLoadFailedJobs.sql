/****** Object:  StoredProcedure [dbo].[ResetLoadFailedJobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE ResetLoadFailedJobs
/****************************************************
**
**	Desc:	Looks for jobs with process state 9 = Load Failed
**			Resets the them to state 10 = New if Retry_Load_Count is less than the maximum
**			Otherwise, sets them to state 3 = Load Failed
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	
**	Auth:	mem
**	Date:	10/12/2010 mem - Initial Version
**    
*****************************************************/
(
	@infoOnly tinyint = 0
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @message varchar(256)
	
	declare @job int	
	declare @continue tinyint

	declare @RetryLoadCount int
	declare @MaxRetryLoadCount int
	Set @MaxRetryLoadCount = 5

	Set @message = ''
	Set @infoOnly = IsNull(@infoOnly, 0)
	
	------------------------------------
	-- Process each job in T_Analysis_Description with state 9
	------------------------------------	
	--
	set @job = -1
	set @continue = 1
	
	While @continue = 1
	Begin
		SELECT TOP 1 @Job = Job, 
		             @RetryLoadCount = Retry_Load_Count
		FROM T_Analysis_Description
		WHERE Job > @job AND Process_State = 9
		ORDER BY Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin
			
			If @RetryLoadCount < @MaxRetryLoadCount
			Begin
				Set @RetryLoadCount = @RetryLoadCount + 1
				
				If @infoOnly <> 0
				Begin
					Print 'Need to retry job ' + Convert(varchar(12), @Job)
				End
				Else
				Begin
					
					UPDATE T_Analysis_Description 
					SET Process_State = 10, 
						Retry_Load_Count = @RetryLoadCount, 
						Last_Affected = GETDATE()
					WHERE (Job = @Job)
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					
					Set @message = 'Load failed for job ' + Convert(varchar(12), @job) + ' due to file I/O error; resetting to state new'
					Exec PostLogEntry 'Warning', @message, 'ResetLoadFailedJobs'
				End
			End
			Else
			Begin
				-- Job has already been retried @MaxRetryLoadCount times; set the state to 3 = Load Failed
				
				If @infoOnly <> 0
				Begin
					print 'Load failed ' + Convert(varchar(12), @MaxRetryLoadCount) + ' times for job ' + Convert(varchar(12), @job) + '; job state will be set to 3'
				End
				Else
				Begin
					
					UPDATE T_Analysis_Description 
					SET Process_State = 3, 
						Last_Affected = GETDATE()
					WHERE (Job = @Job)
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					
					
					Set @message = 'Load failed ' + Convert(varchar(12), @MaxRetryLoadCount) + ' times for job ' + Convert(varchar(12), @job) + '; job state set to 3'
					Exec PostLogEntry 'Error', @message, 'ResetLoadFailedJobs'
				End
			End
		
		End
	End
		
	return @myError


GO
