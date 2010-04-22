/****** Object:  StoredProcedure [dbo].[GetErrorsFromSingleDB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure dbo.GetErrorsFromSingleDB
/****************************************************
** 
**	Desc:	Appends log entries from the specific DB to temporary table #LE
**          The calling procedure must create this table prior to calling this procedure
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	02/19/2008
**    
*****************************************************/
(
	@Server varchar(128),
	@DatabaseName varchar(256),
	@errorsOnly tinyint,
	@MaxLogEntriesPerDB int,
	@message varchar(255) = '' OUTPUT
)
As	
	Set nocount on
	
	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	set @message = ''
	
	Declare @Sql nvarchar(2048)
	Declare @CurrentServerPrefix varchar(128)

	-- If @Server is actually this server, then we do not need to prepend table names with the text
	If Lower(@Server) = Lower(@@ServerName)
		Set @CurrentServerPrefix = ''
	Else
		Set @CurrentServerPrefix = @Server + '.'
	
	---------------------------------------------------
	-- Populate two variables that specify the fields to select and the fields to insert the data into
	---------------------------------------------------
	
	Declare @SqlInsert nvarchar(256)
	Set @SqlInsert = ' INSERT INTO #LE (Server_Name, DBName, Entry_ID, posted_by, posting_time, type, message, Entered_By)'

	Declare @SqlSrcFields nvarchar(512)
	Set @SqlSrcFields = '''' + @Server + ''', ''' + @DatabaseName + ''', Entry_ID, posted_by, posting_time, type, message, Entered_By'
						
	---------------------------------------------------
	-- Get error log entries from the target DB; place in the #LE temporary table
	---------------------------------------------------

	Set @Sql = ''   + @SqlInsert
	Set @Sql = @Sql + ' SELECT ' + @SqlSrcFields
	Set @Sql = @Sql + ' FROM ' + @CurrentServerPrefix + '[' + @DatabaseName + '].dbo.T_Log_Entries'
	Set @Sql = @Sql + ' WHERE type = ''error'''
	Set @Sql = @Sql + ' ORDER BY Entry_ID'
				
	EXEC sp_executesql @Sql	
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount	


	if @errorsOnly = 0
	Begin
		---------------------------------------------------
		-- Get non-error log entries from the target DB; place in the #LE temporary table
		---------------------------------------------------

		Set @Sql = ''   + @SqlInsert

		if @MaxLogEntriesPerDB <= 0
			Set @Sql = @Sql + ' SELECT '
		else
			Set @Sql = @Sql + ' SELECT TOP ' + Convert(varchar(24), @MaxLogEntriesPerDB) + ' '
		
		Set @Sql = @Sql + @SqlSrcFields
		Set @Sql = @Sql + ' FROM ' + @CurrentServerPrefix + '[' + @DatabaseName + '].dbo.T_Log_Entries'
		Set @Sql = @Sql + ' WHERE type <> ''error'''
		Set @Sql = @Sql + ' ORDER BY Entry_ID'

		EXEC sp_executesql @Sql	
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount	

	End
	
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[GetErrorsFromSingleDB] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetErrorsFromSingleDB] TO [MTS_DB_Lite] AS [dbo]
GO
