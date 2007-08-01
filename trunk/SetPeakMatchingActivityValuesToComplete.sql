/****** Object:  StoredProcedure [dbo].[SetPeakMatchingActivityValuesToComplete] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.SetPeakMatchingActivityValuesToComplete
/****************************************************
**
**	Desc: Updates T_Peak_Matching_Activity and T_Peak_Matching_History for the given task
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
	@mtdbName varchar (128)
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

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
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError


GO
GRANT EXECUTE ON [dbo].[SetPeakMatchingActivityValuesToComplete] TO [DMS_SP_User]
GO
