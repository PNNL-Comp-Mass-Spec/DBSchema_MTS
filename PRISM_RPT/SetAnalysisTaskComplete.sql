/****** Object:  StoredProcedure [dbo].[SetAnalysisTaskComplete] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.SetAnalysisTaskComplete
/****************************************************
**
**	Desc: Sets status of analysis job to successful
**        completion and processes analysis results
**        or sets status to failed (according to
**        value of input argument).
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @jobNum					Unique identifier for analysis job
**	  @completionCode			0->success, 1->failure, anything else ->no intermediate files
**	  @resultsFolderName		Name of folder that contains analysis results
**	  @comment					New comment
**
**	Auth:	mem
**	Date:	01/05/2008
**
*****************************************************/
(
    @jobNum int,
    @completionCode int = 0,				-- 0 means no error; otherwise, the error code
    @resultsFolderName varchar(64),			-- Not used in this procedure
    @comment varchar(255),					-- Note that the Analysis Manager will have appended any new messages to the existing comment
    @organismDBName varchar(64) = ''		-- Not used in this procedure
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @message varchar(512)
	Declare @JobText varchar(64)
	Set @JobText = 'Job ' + Convert(varchar(12), @jobNum)
	Set @message = ''

	Declare @ToolID int
	Declare @TaskID int
	Declare @ServerName varchar(128)
	Declare @DatabaseName varchar(128)

	Declare @JobStateID int
	Declare @ErrorCode int
	Declare @WarningCode int
	Declare @AnalysisResultsID int

	Set @ErrorCode = @completionCode
	Set @WarningCode = Null
	Set @AnalysisResultsID = Null
	
	---------------------------------------------------
	-- Lookup the analysis tool ID and other parameters for job @jobNum
	---------------------------------------------------
	SELECT @ToolID = Tool_ID,
		   @TaskID = Task_ID,
		   @ServerName = Task_Server,
		   @DatabaseName = Task_Database,
		   @WarningCode = Analysis_Manager_Warning,
		   @AnalysisResultsID = Analysis_Manager_ResultsID
	FROM T_Analysis_Job
	WHERE (Job_ID = @jobNum)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount = 0
	Begin
		Set @message = @JobText + ' not found in T_Analysis_Job'
		Set @myError = 50005
		Goto Done
	End
	
	Set @ToolID = IsNull(@ToolID, 0)

	---------------------------------------------------
	-- Update analysis job according to completion parameters
	---------------------------------------------------
	
	If @completionCode = 0  
		Set @JobStateID = 3		-- Job completed
	Else
		Set @JobStateID = 4		-- Job failed for unknown reasons


	UPDATE T_Analysis_Job 
	SET Job_Finish = GetDate(), 
		State_ID = @JobStateID,
		Comment = @comment
	WHERE (Job_ID = @jobNum)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
		
	If @myError <> 0
	Begin
		-- Update failed
		set @message = 'Update operation in T_Analysis_Job failed for ' + @JobText + '; error code ' + Convert(varchar(12), @myError)
		Goto Done
	End
	
	If @ToolID = 1
	Begin
		---------------------------------------------------
		-- Viper
		---------------------------------------------------
	
		Exec SetPeakMatchingTaskCompleteMaster
			@taskID,
			@ServerName,
			@DatabaseName,
			@ErrorCode,
			@WarningCode,
			@AnalysisResultsID,		-- MDID
			@message output,
			@jobNum,
			@JobStateID
	End
	
	If @ToolID = 2
	Begin
		---------------------------------------------------
		-- MultiAlign
		---------------------------------------------------

		Exec SetMultiAlignTaskCompleteMaster
			@taskID,
			@serverName,
			@DatabaseName,
			@ErrorCode,
			@WarningCode,
			@AnalysisResultsID,
			@message output,
			@jobNum,
			@JobStateID

	End
	
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	
	if @myError <> 0
		RAISERROR (@message, 10, 1)
		
	return @myError

GO
GRANT EXECUTE ON [dbo].[SetAnalysisTaskComplete] TO [DMS_SP_User]
GO
