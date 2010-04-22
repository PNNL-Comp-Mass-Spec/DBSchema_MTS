/****** Object:  StoredProcedure [dbo].[SetPeakMatchingTaskToRestartMaster] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure dbo.SetPeakMatchingTaskToRestartMaster
/****************************************************
**
**	Desc: Calls SetPeakMatchingTaskToRestart in the specified database on the specified server
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	06/14/2006
**			01/03/2008 mem - Now using T_Analysis_Job to track assigned tasks
**			
*****************************************************/
(
	@taskID int,
	@serverName varchar(128),
	@mtdbName varchar (128),
	@message varchar(512) output
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
	
	---------------------------------------------------
	-- Call SetPeakMatchingActivityValuesToComplete to update
	-- T_Peak_Matching_Activity and T_Analysis_Job for the given task
	---------------------------------------------------
	--
	Exec SetPeakMatchingActivityValuesToComplete @taskID, @serverName, @mtdbName
								
	---------------------------------------------------
	-- Call SetPeakMatchingTaskToRestart in the given database
	---------------------------------------------------
	
	-- Construct the working server prefix
	If Lower(@@ServerName) = Lower(@serverName)
		Set @WorkingServerPrefix = ''
	Else
		Set @WorkingServerPrefix = @serverName + '.'
	
	set @SPToExec = @WorkingServerPrefix + '[' + @mtdbname + '].dbo.SetPeakMatchingTaskToRestart'

	exec @myError = @SPToExec	@taskID, 
								@message = @message Output

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError


GO
GRANT EXECUTE ON [dbo].[SetPeakMatchingTaskToRestartMaster] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[SetPeakMatchingTaskToRestartMaster] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[SetPeakMatchingTaskToRestartMaster] TO [MTS_DB_Lite] AS [dbo]
GO
