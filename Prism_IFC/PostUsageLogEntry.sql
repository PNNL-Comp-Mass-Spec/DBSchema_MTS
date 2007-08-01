/****** Object:  StoredProcedure [dbo].[PostUsageLogEntry] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.PostUsageLogEntry
/****************************************************
**
**	Desc: Put new entry into T_Usage_Log and update T_Usage_Stats
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**	Auth:	mem
**	Date:	10/22/2004
**			07/29/2005 mem - Added parameter @MinimumUpdateInterval
**			03/16/2006 mem - Now updating T_Usage_Stats
**			03/17/2006 mem - Now populating Usage_Count in T_Usage_Log and changed @MinimumUpdateInterval from 6 hours to 1 hour
**    
*****************************************************/
(
	@postedBy varchar(255),
	@DBName varchar(128) = '',
	@message varchar(500) = '',
	@MinimumUpdateInterval int = 1			-- Set to a value greater than 0 to limit the entries to occur at most every @MinimumUpdateInterval hours
)
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
	
	-- Update entry for @postedBy in T_Usage_Stats
	If Not Exists (SELECT Posted_By FROM T_Usage_Stats WHERE Posted_By = @postedBy)
		INSERT INTO T_Usage_Stats (Posted_By, Last_Posting_Time, Usage_Count)
		VALUES (@postedBy, GetDate(), 1)
	Else
		UPDATE T_Usage_Stats 
		SET Last_Posting_Time = GetDate(), Usage_Count = Usage_Count + 1
		WHERE Posted_By = @postedBy

	
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
				(Posted_By, Posting_Time, Target_DB_Name, Message, Calling_User, Usage_Count) 
		SELECT @postedBy, GetDate(), @DBName, @message, @CallingUser, S.Usage_Count
		FROM T_Usage_Stats S
		WHERE S.Posted_By = @postedBy
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myRowCount <> 1 Or @myError <> 0
		begin
			Set @message = 'Update was unsuccessful for T_Usage_Log table: @myRowCount = ' + Convert(varchar(19), @myRowCount) + '; @myError = ' + Convert(varchar(19), @myError)
			execute PostLogEntry 'Error', @message, 'PostUsageLogEntry'
		end
	End
	
	RETURN 0

GO
GRANT EXECUTE ON [dbo].[PostUsageLogEntry] TO [DMS_SP_User]
GO
