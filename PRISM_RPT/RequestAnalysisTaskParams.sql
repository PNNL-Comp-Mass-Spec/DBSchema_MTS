/****** Object:  StoredProcedure [dbo].[RequestAnalysisTaskParams] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.RequestAnalysisTaskParams 
/****************************************************
**
**	Desc: 
**	Called by analysis manager
**  to get information that it needs to perform the task.
**
**	All information needed for task is returned
**	in the output resultset
**
**	Return values: 0: success, anything else: error
**
**	Auth: mem
**	Date: 01/04/2008
**    
*****************************************************/
(
	@EntityId int,
	@message varchar(512)='' output
)
AS
	Set nocount on

	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0
	
	Set @message = ''

	Declare @ToolID int
	Declare @ToolIDValid tinyint
	Set @ToolIDValid = 0
	
	Declare @jobNum int
	Set @jobNum = @EntityId
	
	Declare @JobText varchar(64)
	Set @JobText = 'Job ' + Convert(varchar(12), @jobNum)
	
	Declare @S varchar(1024)
	Declare @ViewName varchar(128)
	
	---------------------------------------------------
	-- Lookup the analysis tool ID for job @jobNum
	---------------------------------------------------
	SELECT @ToolID = Tool_ID
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

	If @ToolID = 1
	Begin
		-- VIPER
		Set @ToolIDValid = 1
		Set @ViewName  = 'V_Peak_Matching_Params_Cached'
	End

	If @ToolID = 2
	Begin
		-- MultiAlign
		Set @ToolIDValid = 1
		Set @ViewName  = 'V_MultiAlign_Params_Cached'
	End
	
	If @ToolIDValid = 0
	Begin
		Set @message = 'Unknown Tool_ID for ' + @JobText + '; unable to return any records'
		Set @myError = 50006
		Goto Done
	End
	Else
	Begin
		Set @S = 'SELECT * FROM ' + @ViewName + ' WHERE JobNum = ' + Convert(varchar(12), @jobNum)
		Exec (@S)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount


		if @myError <> 0
		begin
			Set @message = 'Unable to retrieve analsis job parameters from ' + @ViewName + ' for ' + @JobText
			goto done
		end
		
		If @myRowCount = 0
		Begin
			Set @message = @JobText + ' not found in ' + @ViewName
			Set @myError = 50005
			Goto Done
		End
		
		if @myRowCount <> 1 
		begin
			Set @myError = 50005
			Set @message = 'Invalid number of rows returned from ' + @ViewName + ' while getting analysis job params for ' + @JobText
			goto done
		end
	End
	
  	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:

	If @myError <> 0
	Begin
		Print @message
		Exec PostLogEntry 'Error', @message, 'RequestAnalysisTaskParams', 1
	End
	
	return @myError

GO
GRANT EXECUTE ON [dbo].[RequestAnalysisTaskParams] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RequestAnalysisTaskParams] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RequestAnalysisTaskParams] TO [MTS_DB_Lite] AS [dbo]
GO
