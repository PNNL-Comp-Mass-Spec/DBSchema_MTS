SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SetPeakMatchingTaskToRestartMaster]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[SetPeakMatchingTaskToRestartMaster]
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
	-- T_Peak_Matching_Activity and T_Peak_Matching_History for the given task
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[SetPeakMatchingTaskToRestartMaster]  TO [DMS_SP_User]
GO

