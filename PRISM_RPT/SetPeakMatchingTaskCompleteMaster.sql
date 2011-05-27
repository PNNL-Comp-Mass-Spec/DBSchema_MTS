/****** Object:  StoredProcedure [dbo].[SetPeakMatchingTaskCompleteMaster] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.SetPeakMatchingTaskCompleteMaster
/****************************************************
**
**	Desc: Calls SetPeakMatchingTaskComplete in the specified database on the specified server
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	05/20/2003   
**			07/01/2003
**			08/13/2003
**			09/19/2003
**			12/12/2004 mem - Ported to PRISM_RPT and added @serverName parameter
**			01/03/2005 mem - No longer posting error messages to this DB since they're already posted in the working DB
**			05/20/2005 mem - Now updating T_Peak_Matching_History with the completion time
**			11/23/2005 mem - Added brackets around @mtdbname as needed to allow for DBs with dashes in the name
**			06/14/2006 mem - Added call to SetPeakMatchingActivityValuesToComplete and updated call to SetPeakMatchingTaskComplete to not pass parameter @mtdbName
**			01/04/2008 mem - Now using T_Analysis_Job to track assigned tasks
**			10/14/2010 mem - Moved call to SetPeakMatchingActivityValuesToComplete to occur after call to SetPeakMatchingTaskComplete
**
*****************************************************/
(
	@taskID int,
	@serverName varchar(128),
	@mtdbName varchar (128),
	@errorCode int = 0,
	@warningCode int = 0,
	@MDID int = NULL,						-- MD_ID value in T_Match_Making_Description, if any
	@message varchar(512) output,
	@JobID int = NULL,						-- Job number in T_Analysis_Job
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
	-- Call SetPeakMatchingTaskComplete in the given database
	---------------------------------------------------
	
	-- Construct the working server prefix
	If Lower(@@ServerName) = Lower(@serverName)
		Set @WorkingServerPrefix = ''
	Else
		Set @WorkingServerPrefix = @serverName + '.'
	
	set @SPToExec = @WorkingServerPrefix + '[' + @mtdbname + '].dbo.SetPeakMatchingTaskComplete'

	exec @myError = @SPToExec	@taskID, 
								@errorCode, 
								@warningCode, 
								@MDID,
								@message = @message Output

	
	---------------------------------------------------
	-- Call SetPeakMatchingActivityValuesToComplete to update
	--   T_Peak_Matching_Activity and T_Analysis_Job for the given task
	-- This needs to occur after the call to SetPeakMatchingTaskComplete
	--   so that T_Peak_Matching_Task in @mtdbname will have the MD_ID value defined
	---------------------------------------------------
	--
	Exec SetPeakMatchingActivityValuesToComplete @taskID, @serverName, @mtdbName, @JobID, @JobStateID

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[SetPeakMatchingTaskCompleteMaster] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[SetPeakMatchingTaskCompleteMaster] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[SetPeakMatchingTaskCompleteMaster] TO [MTS_DB_Lite] AS [dbo]
GO
