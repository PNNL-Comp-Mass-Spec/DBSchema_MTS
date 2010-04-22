/****** Object:  StoredProcedure [dbo].[ValidateTaskDetailsForJob] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.ValidateTaskDetailsForJob
/****************************************************
**
**	Desc:	Validates that the Task_ID, Server_Name, and Database_Name are correct for the given Job
**			If a discrepancy is found, then updates the values, displays an error message,
**			and optionally logs the error to T_Log_Entries
**
**	Auth:	mem
**	Date:	01/04/2008
**
*****************************************************/
(
	@JobID int, 
	@TaskID int output, 
	@ServerName varchar(128) output, 
	@DatabaseName varchar(128) output,
	@LogErrors tinyint = 1,
	@message varchar(512) = '' output,
	@infoOnly tinyint = 0			-- If Non-zero, then will not update @TaskID, @ServerName, and @DatabaseName if they are incorrect for @JobID; furthermore, will not log errors
)
As
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @TaskIDCurrent int
	Declare @ServerNameCurrent varchar(128)
	Declare @DatabaseNameCurrent varchar(128)
	Declare @JobText varchar(64)
	
	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------

	Set @JobID = IsNull(@JobID, 0)
	Set @TaskID = IsNull(@TaskID, 0)
	Set @ServerName = IsNull(@ServerName, '??')
	Set @DatabaseName = IsNull(@DatabaseName, '??')
	Set @LogErrors = IsNull(@LogErrors, 1)
	Set @message = ''
	Set @infoOnly = IsNull(@infoOnly, 0)
	
	Set @JobText = 'Job ' + Convert(varchar(12), @JobID)
	
	---------------------------------------------------
	-- Lookup the values for @JobID in T_Analysis_Job
	---------------------------------------------------
	
	SELECT	@TaskIDCurrent = Task_ID, 
			@ServerNameCurrent = Task_Server, 
			@DatabaseNameCurrent = Task_Database
	FROM T_Analysis_Job
	WHERE (Job_ID = @JobID)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount = 0
	Begin
		Set @message = @JobText + ' not found in T_Analysis_Job'
		Set @myError = 54000
		Goto Done		
	End
	
	Set @TaskIDCurrent = IsNull(@TaskIDCurrent, 0)
	Set @ServerNameCurrent = IsNull(@ServerNameCurrent, '')
	Set @DatabaseNameCurrent = IsNull(@DatabaseNameCurrent, '')
	
	If @TaskID <> @TaskIDCurrent
	Begin
		If Len(@message) > 0
			Set @message = @message + '; '
		Set @message = @message + 'TaskID mismatch: ' + Convert(varchar(12), @TaskIDCurrent) + ' in T_Analysis_Job vs. ' + Convert(varchar(12), @TaskID) + ' in @TaskID'
		
		If @infoOnly = 0
			Set @TaskID = @TaskIDCurrent
	End

	If @ServerName <> @ServerNameCurrent
	Begin
		If Len(@message) > 0
			Set @message = @message + '; '
		Set @message = @message + 'ServerName mismatch: ' + @ServerNameCurrent + ' in T_Analysis_Job vs. ' + @ServerName + ' in @ServerName'
		
		If @infoOnly = 0
			Set @ServerName = @ServerNameCurrent
	End

	If @DatabaseName <> @DatabaseNameCurrent
	Begin
		If Len(@message) > 0
			Set @message = @message + '; '
		Set @message = @message + 'DBName mismatch: ' + @DatabaseNameCurrent + ' in T_Analysis_Job vs. ' + @DatabaseName + ' in @DatabaseName'
		
		If @infoOnly = 0
			Set @DatabaseName = @DatabaseNameCurrent
	End
	
	If Len(@message) > 0
	Begin
		If @infoOnly = 0
		Begin
			If @LogErrors <> 0
				Exec PostLogEntry 'Error', @message, 'ValidateTaskDetailsForJob', 1
		End
		Else
		Begin
			Print @message
		End
	End
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[ValidateTaskDetailsForJob] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ValidateTaskDetailsForJob] TO [MTS_DB_Lite] AS [dbo]
GO
