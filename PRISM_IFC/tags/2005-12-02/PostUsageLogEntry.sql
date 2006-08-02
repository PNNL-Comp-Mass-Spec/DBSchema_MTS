SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[PostUsageLogEntry]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[PostUsageLogEntry]
GO

CREATE PROCEDURE dbo.PostUsageLogEntry
/****************************************************
**
**	Desc: Put new entry into T_Usage_Log
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**		Auth:	mem
**		Date:	10/22/2004
**				07/29/2005 mem - Added parameter @MinimumUpdateInterval
**    
*****************************************************/
	@postedBy varchar(255),
	@DBName varchar(128) = '',
	@message varchar(500) = '',
	@MinimumUpdateInterval int = 6			-- Set to a value greater than 0 to limit the entries to occur at most every @MinimumUpdateInterval hours
As
	set nocount on
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @CallingUser varchar(128)
	Set @CallingUser = SUSER_SNAME()

	declare @PostEntry tinyint
	Set @PostEntry = 1

	Declare @LastUpdated varchar(64)
		
	if @MinimumUpdateInterval > 0
	Begin
		-- See if the last update was less than @MinimumUpdateInterval hours ago

		Set @LastUpdated = '1/1/1900'
		
		SELECT @LastUpdated = MAX(Posting_time)
		FROM T_Usage_Log
		WHERE Posted_By = @postedBy AND Calling_User = @CallingUser
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		IF @myRowCount = 1
		Begin
			If GetDate() <= DateAdd(hour, @MinimumUpdateInterval, IsNull(@LastUpdated, '1/1/1900'))
				Set @PostEntry = 0
		End
	End

      
    If @PostEntry = 1
    Begin  
		INSERT INTO T_Usage_Log
				(Posted_By, Posting_Time, Target_DB_Name, Message, Calling_User) 
		VALUES	(@postedBy, GetDate(), @DBName, @message, @CallingUser)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myRowCount <> 1
		begin
			RAISERROR ('Update was unsuccessful for T_Log_Entries table', 10, 1)
			return 51191
		end
	End
	
	RETURN 0

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[PostUsageLogEntry]  TO [DMS_SP_User]
GO

