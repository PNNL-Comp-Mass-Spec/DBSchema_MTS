/****** Object:  StoredProcedure [dbo].[LocalErrorHandler] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.LocalErrorHandler
/****************************************************
** 
**	Desc:	This procedure should be called from within a Try...Catch block
**			It will generate an error description and optionally log the error
**			It also returns the Error Severity and Error Number via output parameters
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	11/30/2006
**			01/03/2008 mem - Added parameter @duplicateEntryHoldoffHours
**    
*****************************************************/
(
	@CallingProcName varchar(128)='',			-- Optionally provide the calling procedure name; if not provided then uses ERROR_PROCEDURE()
	@CallingProcLocation varchar(128)='',		-- Custom description of the location within the calling procedure within which the error occurred
	@LogError tinyint = 0,						-- Set to 1 to log the error in T_Log_Entries
	@DisplayError tinyint = 0,					-- Set to 1 to display the error via SELECT @message
	@LogWarningErrorList varchar(512) = '1205',	-- Comma separated list of errors that should be treated as warnings if logging to T_Log_Entries
	@ErrorSeverity int=0 output,
	@ErrorNum int=0 output,
	@message varchar(512)='' output,			-- Populated with a description of the error
	@duplicateEntryHoldoffHours int = 0			-- Set this to a value greater than 0 to prevent duplicate entries being posted within the given number of hours
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'
	
	Declare @ErrorState int
	Declare @ErrorProc varchar(256)
	Declare @ErrorLine int
	Declare @ErrorMessage varchar(256)
	Declare @LogErrorType varchar(64)
	
	Begin Try
		Set @CurrentLocation = 'Validating the inputs'
		
		-- Validate the inputs
		Set @CallingProcName = IsNull(@CallingProcName, '')
		Set @CallingProcLocation = IsNull(@CallingProcLocation, '')
		Set @LogError = IsNull(@LogError, 0)
		Set @DisplayError = IsNull(@DisplayError, 0)
		Set @ErrorSeverity = 0
		Set @ErrorNum = 0
		Set @message = ''

		-- Lookup current error information
		Set @CurrentLocation = 'Populating the error tracking variables'
		SELECT
			@ErrorSeverity = IsNull(ERROR_SEVERITY(), 0),
			@ErrorNum = IsNull(ERROR_NUMBER(), 0),
			@ErrorState = IsNull(ERROR_STATE(), 0),
			@ErrorProc = IsNull(ERROR_PROCEDURE(), ''),
			@ErrorLine = IsNull(ERROR_LINE(), 0),
			@ErrorMessage = IsNull(ERROR_MESSAGE(), '')

		-- Generate the error description
		Set @CurrentLocation = 'Generating the error description'
		If Len(IsNull(@ErrorProc, '')) = 0
		Begin
			-- Update @ErrorProc using @CallingProcName
			If len(@CallingProcName) = 0
				Set @CallingProcName = 'Unknown Procedure'
			
			Set @ErrorProc = @CallingProcName
		End
		
		-- Update @CallingProcName using @ErrorProc (required for calling PostLogEntry)
		Set @CallingProcName = @ErrorProc 

		If @ErrorNum = 0 And Len(@ErrorMessage) = 0
			Set @message = 'No Error for ' + @ErrorProc
		Else
		Begin
			Set @message = 'Error caught in ' + @ErrorProc
			If Len(@CallingProcLocation) > 0
				Set @message = @message + ' at "' + @CallingProcLocation + '"'
			Set @message = @message + ': ' + @ErrorMessage + '; Severity ' + Convert(varchar(12), @ErrorSeverity) + '; Error ' + Convert(varchar(12), @ErrorNum) + '; Line ' + Convert(varchar(12), @ErrorLine)
		End

		If @LogError <> 0
		Begin
			Set @CurrentLocation = 'Examining @LogWarningErrorList'
			If Exists (SELECT Value FROM dbo.udfParseDelimitedIntegerList(@LogWarningErrorList, ',') WHERE Value = @ErrorNum)
				Set @LogErrorType = 'Warning'
			Else
				Set @LogErrorType = 'Error'
				
			Set @CurrentLocation = 'Calling PostLogEntry'
			execute PostLogEntry @LogErrorType, @message, @CallingProcName, @duplicateEntryHoldoffHours
		End

		If @DisplayError <> 0
			SELECT @message as Error_Description

	End Try
	Begin Catch
		Set @message = 'Error ' + @CurrentLocation + ' in LocalErrorHandler: ' + IsNull(ERROR_MESSAGE(), '?') + '; Error ' + Convert(varchar(12), IsNull(ERROR_NUMBER(), 0))
		Set @myError = ERROR_NUMBER()
		SELECT @message as Error_Description
	End Catch

	RETURN @myError


GO
GRANT EXECUTE ON [dbo].[LocalErrorHandler] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[LocalErrorHandler] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[LocalErrorHandler] TO [MTS_DB_Lite] AS [dbo]
GO
