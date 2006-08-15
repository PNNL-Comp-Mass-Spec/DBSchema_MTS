/****** Object:  StoredProcedure [dbo].[GetCurrentActivitySummary]    Script Date: 08/14/2006 20:23:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure dbo.GetCurrentActivitySummary
/****************************************************
** 
**		Desc: Returns a combined Current Activity report 
**			  from all servers in V_Active_MTS_Servers
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth:	mem
**		Date:	12/06/2004
**    
*****************************************************/
	@ServerFilter varchar(128) = '',				-- If supplied, then only examines the databases on the given Server
	@message varchar(255) = '' OUTPUT
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	-- Validate or clear the input/output parameters
	Set @ServerFilter = IsNull(@ServerFilter, '')
	Set @message = ''

	declare @Sql nvarchar(1024)
	declare @result int
	set @result = 0
	
	declare @ProcessSingleServer tinyint
	
	If Len(@ServerFilter) > 0
		Set @ProcessSingleServer = 1
	Else
		Set @ProcessSingleServer = 0

	declare @Server varchar(128)
	declare @ServerID int
	declare @MTMain varchar(128)

	declare @Continue int
	declare @processCount int			-- Count of servers processed

	-----------------------------------------------------------
	-- Create the table to hold the stats
	-----------------------------------------------------------
	CREATE TABLE #CurrentActivity (
		[Server_Name] varchar(64) NOT NULL,
		[DBName] varchar(128) NOT NULL,
		[Activity Synopsis] varchar(512) NULL,
		[Duration (minutes)] int NULL,
		[Began] datetime NULL,
		[Completed] datetime NULL
	) 
	
	-----------------------------------------------------------
	-- Process each server in V_Active_MTS_Servers
	-----------------------------------------------------------
	--
	set @processCount = 0
	set @ServerID = -1
	set @Continue = 1
	--	
	While @Continue > 0 and @myError = 0
	Begin -- <A>

		SELECT TOP 1
			@ServerID = Server_ID,
			@Server = Server_Name
		FROM  V_Active_MTS_Servers
		WHERE Server_ID > @ServerID
		ORDER BY Server_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Could not get next entry from V_Active_MTS_Servers'
			set @myError = 50001
			goto Done
		end
		Set @continue = @myRowCount

		If @continue > 0 And (@ProcessSingleServer = 0 Or Lower(@Server) = Lower(@ServerFilter))
		Begin -- <B>

			-- If @Server is actually this server, then we do not need to prepend table names with the text
			If Lower(@Server) = Lower(@@ServerName)
				Set @MTMain = 'MT_Main.dbo.'
			Else
				Set @MTMain = @Server + '.MT_Main.dbo.'
				
			---------------------------------------------------
			-- Populate #CurrentActivity temporary table 
			---------------------------------------------------
			
			Set @Sql = ''
			Set @Sql = @Sql + ' INSERT INTO #CurrentActivity'
			Set @Sql = @Sql + '  (Server_Name, DBName, [Activity Synopsis], [Duration (minutes)], [Began], [Completed])'
			Set @Sql = @Sql + ' SELECT ''' + @Server + ''', [Database], [Activity Synopsis], [Duration (minutes)], [Began], [Completed]'
			Set @Sql = @Sql + ' FROM ' + @MTMain + 'V_Current_Activity_Email'

			EXEC @result = sp_executesql @Sql
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			Set @processCount = @processCount + 1
			
		End -- </B>
			
	End -- </A>
	
	-----------------------------------------------------------
	-- Return the data
	-----------------------------------------------------------
	--
	SELECT * FROM #CurrentActivity
	ORDER BY Server_Name, DBName
		--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Error returning data from #CurrentActivity'
		set @myError = 50004
		goto Done
	end
	
Done:
	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--
	if @myError <> 0
	begin
		If Len(@message) = 0
			set @message = 'Error obtaining statistics; Error code: ' + convert(varchar(32), @myError)

		Exec PostLogEntry 'Error', @message, 'GetCurrentActivitySummary'
	end

	return @myError

GO
GRANT EXECUTE ON [dbo].[GetCurrentActivitySummary] TO [MTUser]
GO
