SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[MasterUpdateStepUnpauseIfIdle]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[MasterUpdateStepUnpauseIfIdle]
GO

CREATE PROCEDURE dbo.MasterUpdateStepUnpauseIfIdle
/****************************************************
** 
**	Desc:	Calls SQLServerAgentJobStats to count the number of jobs running; 
**			if none are running (ignoring those with @JobNameExclusionFilter in the name), then will 
**			unpause any paused update steps in T_Process_Step_Control
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	mem
**	Date:	03/11/2006
**			03/14/2006 mem - Added parameter @JobCategoryExclusionFilter
**    
*****************************************************/
(
	@JobNameExclusionFilter varchar(128) = '%Unpause%',
	@JobCategoryExclusionFilter varchar(128) = '%Continuous%',
	@JobRunningCount int = 0 output,
	@message varchar(255) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	set @JobRunningCount = 0
	set @message = ''
	
	--------------------------------------------
	-- Count the number of jobs running using SQLServerAgentJobStats
	--------------------------------------------
	--
	Set @JobRunningCount = 0
	Exec @myError = SQLServerAgentJobStats @JobNameExclusionFilter, @JobCategoryExclusionFilter, @JobRunningCount = @JobRunningCount output
	
	If @myError <> 0
	Begin
		Set @message = 'Error calling SQLServerAgentJobStats'
		execute PostLogEntry 'Error', @message, 'MasterUpdateStepUnpauseIfIdle', 6
		Goto Done
	End
	
	If @JobRunningCount = 0
	Begin
		Exec MasterUpdateStepPauseControl @Pause = 0, @PostLogEntry = 1, @message = @message output
	End
	Else
		Set @message = 'Found ' + Convert(varchar(12), @JobRunningCount) + ' running job(s)'
		
Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

