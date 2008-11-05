/****** Object:  StoredProcedure [dbo].[AckError] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.AckError
/****************************************************
**
**	Desc: 
**		Acknowledges an error in T_Log_Entries by changing its type from 'Error' to 'ErrorIgnore'
**		If the entry is not of type 'Error', then it is ignored
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	02/19/2008
**    
*****************************************************/
(
	@ErrorEntryID int,
	@TypeToMatch varchar(24) = 'Error',
	@TypeToSwitchTo varchar(24) = 'ErrorIgnore',
	@message varchar(255)='' OUTPUT
)
AS

	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------

	Set @ErrorEntryID = IsNull(@ErrorEntryID, 0)
	Set @TypeToMatch = IsNull(@TypeToMatch, 'Error')
	Set @TypeToSwitchTo = IsNull(@TypeToSwitchTo, 'ErrorIgnore')
	Set @message= ''
	
	Declare @EntryIDType varchar(128)

	Declare @EntryIDText varchar(24)
	Set @EntryIDText = Convert(varchar(24), @ErrorEntryID)
	
	---------------------------------------------------
	-- Update T_Log_Entries
	---------------------------------------------------

	UPDATE T_Log_Entries
	SET Type = @TypeToSwitchTo
	WHERE Entry_ID = @ErrorEntryID AND Type = @TypeToMatch
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myRowCount = 1
		Set @message = 'Log entry ' + @EntryIDText + ' acknowledged to have type "' + @TypeToMatch + '"; changed type to "' + @TypeToSwitchTo + '"'
	Else
	Begin
		-- Update not successful; see if Entry_ID even exists in T_Log_Entries
		
		SELECT @EntryIDType = Type
		FROM T_Log_Entries
		WHERE Entry_ID = @ErrorEntryID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount = 0
			Set @message = 'Entry ' + @EntryIDText + ' is not present in T_Log_Entries'
		Else
			Set @message = 'Entry ' + @EntryIDText + ' in T_Log_Entries has type "' + @EntryIDType + '"; not updated to type "' + @TypeToSwitchTo + '" since it is not type "' + @TypeToMatch + '"'
	End

	
Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[AckError] TO [DMS_SP_User]
GO
GRANT VIEW DEFINITION ON [dbo].[AckError] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[AckError] TO [MTS_DB_Lite]
GO
