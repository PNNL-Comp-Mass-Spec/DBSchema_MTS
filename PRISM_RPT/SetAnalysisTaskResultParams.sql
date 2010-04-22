/****** Object:  StoredProcedure [dbo].[SetAnalysisTaskResultParams] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.SetAnalysisTaskResultParams
/****************************************************
**
**	Desc: Stores the result parametesr for the given analysis job
**		  in T_Analysis_Job.  This procedure should be called prior
**		  to calling SetAnalysisTaskComplete
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	01/05/2008
**
*****************************************************/
(
    @JobID int,
	@ErrorCode int,
	@WarningCode int,
	@AnalysisResultsID int,
	@message varchar(512)='' output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @JobText varchar(64)
	Set @JobText = 'Job ' + Convert(varchar(12), @JobID)
	Set @message = ''
	
	---------------------------------------------------
	-- Store the values in T_Analysis_Job
	---------------------------------------------------

	UPDATE T_Analysis_Job 
	SET Analysis_Manager_Error = @ErrorCode, 
		Analysis_Manager_Warning = @WarningCode, 
		Analysis_Manager_ResultsID = @AnalysisResultsID
	WHERE (Job_ID = @JobID)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
		
	If @myError <> 0
	Begin
		-- Update failed
		set @message = 'Update operation in T_Analysis_Job failed for ' + @JobText + '; error code ' + Convert(varchar(12), @myError)
		Goto Done
	End
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
		
	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[SetAnalysisTaskResultParams] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[SetAnalysisTaskResultParams] TO [MTS_DB_Lite] AS [dbo]
GO
