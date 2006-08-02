SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SetPeakMatchingTaskCompleteMaster]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[SetPeakMatchingTaskCompleteMaster]
GO

CREATE PROCEDURE dbo.SetPeakMatchingTaskCompleteMaster
/****************************************************
**
**	Desc: 
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 5/20/2003   
**
**		Updated: 07/01/2003
**				 08/13/2003
**				 09/19/2003
**				 12/12/2004 mem - Ported to PRISM_RPT and added @serverName parameter
**				 01/03/2005 mem - No longer posting error messages to this DB since they're already posted in the working DB
**				 05/20/2005 mem - Now updating T_Peak_Matching_History with the completion time
**			     11/23/2005 mem - Added brackets around @mtdbname as needed to allow for DBs with dashes in the name
**
*****************************************************/
	@taskID int,
	@serverName varchar(128),
	@mtdbName varchar (128),
	@errorCode int = 0,
	@warningCode int = 0,
	@MDID int = NULL,				-- MD_ID value in T_Match_Making_Description, if any
	@message varchar(512) output
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
	
	declare @TimeCompleted as datetime
	declare @PMHistoryID int
	
	---------------------------------------------------
	-- Cache the current time and lookup the cached History ID value
	---------------------------------------------------
	Set @TimeCompleted = GetDate()
	
	Set @PMHistoryID = 0
	SELECT	@PMHistoryID = PM_History_ID
	FROM T_Peak_Matching_Activity
	WHERE Server_Name = @serverName AND MTDBName = @mtdbName AND TaskID = @taskID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	---------------------------------------------------
	-- Update T_Peak_Matching_Activity with the current time
	-- Set Working = 0 and increment TasksCompleted
	---------------------------------------------------

	UPDATE T_Peak_Matching_Activity
	SET Working = 0, PM_Finish = @TimeCompleted,
		TasksCompleted = TasksCompleted + 1
	WHERE Server_Name = @serverName AND MTDBName = @mtdbName AND TaskID = @taskID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	---------------------------------------------------
	-- Update T_Peak_Matching_History with the current time
	---------------------------------------------------

	If IsNull(@PMHistoryID, 0) > 0
	Begin
		UPDATE T_Peak_Matching_History
		SET PM_Finish = @TimeCompleted
		WHERE PM_History_ID = @PMHistoryID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End
									
	---------------------------------------------------
	-- Call SetPeakMatchingTaskComplete in the given mtdb
	---------------------------------------------------
	
	-- Construct the working server prefix
	If Lower(@@ServerName) = Lower(@serverName)
		Set @WorkingServerPrefix = ''
	Else
		Set @WorkingServerPrefix = @serverName + '.'
	
	set @SPToExec = @WorkingServerPrefix + '[' + @mtdbname + '].dbo.SetPeakMatchingTaskComplete'

	exec @myError = @SPToExec	@taskID, 
								@mtdbName, 
								@errorCode, 
								@warningCode, 
								@MDID,
								@message = @message

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

GRANT  EXECUTE  ON [dbo].[SetPeakMatchingTaskCompleteMaster]  TO [DMS_SP_User]
GO

