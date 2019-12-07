/****** Object:  StoredProcedure [dbo].[PreviewRequestPeakMatchingTaskMaster] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PreviewRequestPeakMatchingTaskMaster]
/****************************************************
**
**	Desc:	Calls RequestPeakMatchingTaskMaster with @infoOnly=1
**
**	Auth:	mem
**	Date:	12/06/2019 mem - Initial version
**
*****************************************************/
(
	@processorName varchar(128) = '',   -- Will auto-update to 'Pub-50' if blank
    @toolVersion varchar(128)= '',      -- Will auto-update to 'VIPER - 3.49.482, February 24, 2017' if blank
	@message varchar(512) = '' output
)
As
	set nocount on

	Declare @myRowCount Int = 0
	Declare @myError Int = 0

    Set @processorName = IsNull(@processorName, '')
    If Len(@processorName) = 0
        Set @processorName = 'Pub-50'
        
    Set @toolVersion = IsNull(@toolVersion, '')
    If Len(@toolVersion) = 0
        Set @toolVersion = 'VIPER - 3.49.482, February 24, 2017'

    Set @message = ''

    Declare @clientPerspective tinyint=1
    Declare @priorityMin tinyint=1
    Declare @priorityMax tinyint=10
    Declare @restrictToMtdbName tinyint=0
    Declare @taskID int
    Declare @taskPriority tinyint
    Declare @analysisJob int
    Declare @analysisResultsFolderPath varchar(256)
    Declare @serverName varchar(128)=''
    Declare @mtdbName varchar(128)=''
    Declare @taskAvailable tinyint=0
    Declare @DBSchemaVersion real=1
  
    Declare @MinimumPeptideProphetProbability real=0
    Declare @AssignedJobID int
    Declare @CacheSettingsForAnalysisManager tinyint=0

    Declare @CallingProcName varchar(128)=''
    Declare @CurrentLocation varchar(128) = 'Start'

	Begin Try

    
        EXECUTE @myError = RequestPeakMatchingTaskMaster
           @processorName
          ,@clientPerspective
          ,@priorityMin
          ,@priorityMax
          ,@restrictToMtdbName
          ,@taskID OUTPUT
          ,@taskPriority OUTPUT
          ,@analysisJob OUTPUT
          ,@analysisResultsFolderPath OUTPUT
          ,@serverName OUTPUT
          ,@mtdbName OUTPUT
          ,@taskAvailable=@taskAvailable OUTPUT
          ,@message=@message OUTPUT
          ,@DBSchemaVersion=@DBSchemaVersion OUTPUT
          ,@toolVersion=@toolVersion
          ,@MinimumPeptideProphetProbability=@MinimumPeptideProphetProbability OUTPUT
          ,@AssignedJobID=@AssignedJobID OUTPUT
          ,@CacheSettingsForAnalysisManager=@CacheSettingsForAnalysisManager
          ,@infoOnly=1

        Select @taskAvailable as Task_Available, @taskID as TaskID, @serverName as TaskServer, @mtdbName as MTDB, @message As Message

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'PreviewRequestPeakMatchingTaskMaster')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output,
								@duplicateEntryHoldoffHours = 2
		Goto Done
	End Catch

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	Return @myError

GO
GRANT EXECUTE ON [dbo].[PreviewRequestPeakMatchingTaskMaster] TO [PNL\svc-dms] AS [dbo]
GO
