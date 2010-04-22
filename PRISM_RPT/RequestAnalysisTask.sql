/****** Object:  StoredProcedure [dbo].[RequestAnalysisTask] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.RequestAnalysisTask 
/****************************************************
**
**	Desc: Looks for analysis job that is appropriate for the given Processor Name.
**        If found, job is assigned to caller and job ID is returned in @jobNum
**
** Job assignment will be based on the processor name and the associated tools 
** defined in T_Analysis_Job_Processor_Tools
**
** Job assignment logic
** 
** 1. Search for candidate jobs that are in the "New" state whose tool is allowed for the given processor,
** where the jobs are directly associated with a processor group in which the given processor has
** active membership. Order by priority and job number If more than one candidate is found.
** 
** 2. If no candidates were found in step 1, look for candidate jobs that are in the "New" state
** whose tool is allowed for the given processor, where the jobs are either not associated with a processor
** group or are associated with at least one processor group that allows general processing.
** Order by priority and job number If more than one candidate is found.
** 
** A job can be exclusively locked to a specific processor group If that group Declares itself not
** available for general processing, and the job is not associated with any other groups that are
** available for general processing
** 
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @processorName		name of caller's computer
**	  @jobNum				unique identifier for analysis job
**
**	Auth:	mem
**	Date:	01/03/2008
**
*****************************************************/
(
	@processorName varchar(128),
	@jobNum int = 0 output,		-- Job number assigned; 0 If no job available
    @message varchar(512)='' output,
	@infoOnly tinyint = 0,				-- Set to 1 to preview the job that would be returned
	@priorityMin tinyint = 1,						-- only tasks with a priority >= to this value will get returned
	@priorityMax tinyint = 10						-- only tasks with a priority <= to this value will get returned

)
As
	Set nocount on

	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	Declare @jobID int
	Declare @ToolIDValid tinyint
	Set @ToolIDValid = 0
	
	-- The analysis manager expects a non-zero return value If no jobs are available
	-- Code 53000 is used for this
	Declare @jobNotAvailableErrorCode int
	Set @jobNotAvailableErrorCode = 53000
	
	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------
	Set @processorName = IsNull(@processorName, '')
	Set @infoOnly = IsNull(@infoOnly, 0)

	Set @jobNum = 0
	Set @message = ''

	If Len(LTrim(RTrim(@processorName))) = 0
	Begin
		Set @message = 'Processor name is blank'
		Set @myError = 50000
		goto Done
	End
	
	Declare @processorID int
	Set @processorID = 0
	--
	SELECT  @processorID = ID
	FROM T_Analysis_Job_Processors
	WHERE Processor_Name = @processorName
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Error resolving processor name "' + @processorName + '" to ID'
		Set @myError = 50002
		goto Done
	End
	--
	If @processorID = 0
	Begin
		Set @message = 'Invalid processor name "' + @processorName + '"'
		Set @myError = 50003
		goto Done
	End

	Declare @toolVersion varchar(128)
	Set @toolVersion = 'DMSAnalysisManager'

	Declare @taskAvailable tinyint
	Declare @taskID int
	Set @taskAvailable = 0
	Set @taskID = 0
	
	-- See If this processor is allowed to run Viper tasks
	If @taskAvailable = 0 AND EXISTS ( 
	            SELECT *
				FROM T_Analysis_Job_Processors AJP INNER JOIN
					 T_Analysis_Job_Processor_Tools AJTools ON AJP.ID = AJTools.Processor_ID
				WHERE AJP.Processor_Name = @processorName AND AJTools.Tool_ID = 1)
	Begin
		Set @ToolIDValid = 1
		
		Exec RequestPeakMatchingTaskMaster	
					@processorName, 
					@priorityMin = @priorityMin,
					@priorityMax = @priorityMax,
					@taskID = @taskID output,
					@taskAvailable = @taskAvailable output,
					@message = @message output,
					@toolVersion = @toolVersion,
					@AssignedJobID = @jobID output,
					@CacheSettingsForAnalysisManager = 1,
					@infoOnly = @infoOnly

	End


	-- See If this processor is allowed to run MultiAlign tasks
	If @taskAvailable = 0 AND EXISTS ( 
	            SELECT *
				FROM T_Analysis_Job_Processors AJP INNER JOIN
					 T_Analysis_Job_Processor_Tools AJTools ON AJP.ID = AJTools.Processor_ID
				WHERE AJP.Processor_Name = @processorName AND AJTools.Tool_ID = 2)
	Begin
		Set @ToolIDValid = 1
		
		Exec RequestMultiAlignTaskMaster	
					@processorName, 
					@priorityMin = @priorityMin,
					@priorityMax = @priorityMax,
					@taskID = @taskID output,
					@taskAvailable = @taskAvailable output,
					@message = @message output,
					@toolVersion = @toolVersion,
					@AssignedJobID = @jobID output,
					@infoOnly = @infoOnly

	End

	If @ToolIDValid = 0
	Begin
		Set @message = 'Processor "' + @processorName + '" does not have a valid Tool_ID defined in T_Analysis_Job_Processor_Tools; job not assigned'
		Set @myError = 	53001
		Goto Done
	End
	
	If @taskAvailable = 0
	Begin
		Set @message = 'No jobs are available for processor "' + @processorName + '"'
		Set @myError = @jobNotAvailableErrorCode
	End
	Else
	Begin
		Set @message = ''

		If @infoOnly = 0
			Set @jobNum = @jobID
		Else
			Set @message = 'TaskID ' + Convert(varchar(12), @taskID) + ' would be assigned to processor "' + @processorName + '"'
	End

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	If @message <> '' AND @myError <> @jobNotAvailableErrorCode AND @infoOnly = 0
	Begin
		RAISERROR (@message, 10, 1)
	End

	return @myError


GO
GRANT EXECUTE ON [dbo].[RequestAnalysisTask] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RequestAnalysisTask] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RequestAnalysisTask] TO [MTS_DB_Lite] AS [dbo]
GO
