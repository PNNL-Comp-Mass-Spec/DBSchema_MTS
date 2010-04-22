/****** Object:  StoredProcedure [dbo].[SetMultiAlignTaskCompleteMaster] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.SetMultiAlignTaskCompleteMaster
/****************************************************
**
**	Desc: Calls SetMultiAlignTaskComplete in the specified database on the specified server
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	01/04/2008
**
*****************************************************/
(
	@taskID int,
	@serverName varchar(128),
	@mtdbName varchar (128),
	@errorCode int = 0,
	@warningCode int = 0,
	@AnalysisResultsID int = 0,
	@message varchar(512) output,
	@JobID int = NULL,						-- Job number in T_Analysis_Job; if provided, then this procedure verifies that @taskID, @serverName, and @mtdbName are correct for the given Job
	@JobStateID int = 3
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @ErrorMessage varchar(500)
	
	set @ErrorMessage = ''
	set @message = ''

	declare @SPToExec varchar(255)
	declare @WorkingServerPrefix varchar(128)
	
	Set @JobID = IsNull(@JobID, 0)
	
	If @JobID <> 0
	Begin
		-- Make sure @taskID, @serverName, and @mtdbName are correct for job @JobID
		-- If any of the values are wrong, they will get updated
		Exec ValidateTaskDetailsForJob @JobID, @taskID output, @serverName output, @mtdbName output, @LogErrors=1
	End
	
	---------------------------------------------------
	-- Call SetMultiAlignActivityValuesToComplete to update
	-- T_MultiAlign_Activity and T_Analysis_Job for the given task
	---------------------------------------------------
	--
	Exec SetMultiAlignActivityValuesToComplete @taskID, @serverName, @mtdbName, @JobID, @JobStateID


	---------------------------------------------------
	-- Call SetMultiAlignTaskComplete in the given database
	---------------------------------------------------
	
	-- Construct the working server prefix
	If Lower(@@ServerName) = Lower(@serverName)
		Set @WorkingServerPrefix = ''
	Else
		Set @WorkingServerPrefix = @serverName + '.'
	
	set @SPToExec = @WorkingServerPrefix + '[' + @mtdbname + '].dbo.SetMultiAlignTaskComplete'

	exec @myError = @SPToExec	@taskID, 
								@errorCode, 
								@warningCode, 
								@AnalysisResultsID,
								@message = @message Output

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[SetMultiAlignTaskCompleteMaster] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[SetMultiAlignTaskCompleteMaster] TO [MTS_DB_Lite] AS [dbo]
GO
