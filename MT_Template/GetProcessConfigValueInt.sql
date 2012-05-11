/****** Object:  StoredProcedure [dbo].[GetProcessConfigValueInt] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.GetProcessConfigValueInt
/****************************************************
**
**	Desc: Looks up the value for the given setting in T_Process_Config
**		  Returns the value via @ConfigValue
**		  If more than one entry exists for @ConfigKey, then
**		    returns the first one, sorted by Process_Config_ID
**		  If no entry is found, then @ConfigValue is set to @DefaultValue (@ErrorOccurred will be 0)
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**	Auth:	mem
**	Date:	09/06/2007
**			03/28/2012 mem - Added parameters @LogErrors and @ErrorOccurred
**      
*****************************************************/
(
	@ConfigKey varchar(255),
	@DefaultValue int = 0,
	@ConfigValue int output,
	@MatchFound tinyint=0 output,
	@LogErrors tinyint = 1,				-- Set to 1 to log any errors in T_Log_Entries
	@ErrorOccurred tinyint=0 output,	-- Will be 0 if no error, 1 if a conversion error (meaning the entry is not numeric)
	@message varchar(512)='' output

)
As
	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'
	
	Set @ConfigValue = IsNull(@DefaultValue, 0)
	Set @MatchFound = 0
	Set @ErrorOccurred = 0
	Set @message = ''
	
	Begin Try
		SELECT TOP 1 @ConfigValue = Convert(int, Value)
		FROM T_Process_Config
		WHERE [Name] = @ConfigKey
		ORDER BY Process_Config_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @message = 'Entry not found in T_Process_Config for key "' + @ConfigKey + '"'
		Else
			Set @MatchFound = 1
			
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'GetProcessConfigValueInt')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = @LogErrors, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output
		Set @ErrorOccurred = 1								
	End Catch

	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[GetProcessConfigValueInt] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetProcessConfigValueInt] TO [MTS_DB_Lite] AS [dbo]
GO
