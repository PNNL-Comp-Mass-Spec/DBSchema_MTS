/****** Object:  StoredProcedure [dbo].[UpdateDatabaseStatesSingleTable] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure dbo.UpdateDatabaseStatesSingleTable
/****************************************************
** 
**	Desc: Updates the State_ID column in the master DB list tables
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	mem
**	Date:	11/12/2004
**			12/06/2004 mem - Added @RemoteStateIgnoreList parameter
**			12/10/2004 mem - Added query to add missing database names
**			12/15/2004 mem - Now updating Server_ID
**			08/02/2005 mem - Now updating DB_Schema_Version (added parameters @LocalSchemaVersionField and @RemoteSchemaVersionField)
**			08/03/2006 mem - Added parameter @PreviewSql
**			06/25/2008 mem - Updated to allow @RemoteStateIgnoreList to be blank
**			02/05/2010 mem - Added parameters @RemoteDescriptionField, @RemoteOrganismField, and @RemoteCampaignField
**			03/31/2011 mem - Now updating column Last_Online
**    
*****************************************************/
(
	@serverID int = 1,
	@UpdateTableNames tinyint = 1,

	@LocalTableName varchar(128) = 'T_MTS_MT_DBs',
	@LocalIDField varchar(128) = 'MT_DB_ID',
	@LocalNameField varchar(128) = 'MT_DB_Name',
	@LocalStateField varchar(128) = 'State_ID',
	@LocalSchemaVersionField  varchar(128) = 'DB_Schema_Version',
	
	@RemoteTableName varchar(128) = 'T_MT_Database_List',
	@RemoteIDField varchar(128) = 'MTL_ID',
	@RemoteNameField varchar(128) = 'MTL_Name',
	@RemoteStateField varchar(128) = 'MTL_State',
	@RemoteSchemaVersionField  varchar(128) = 'MTL_DB_Schema_Version',

	@RemoteDescriptionField varchar(128) = '',			-- If blank, then this field is not updated
	@RemoteOrganismField varchar(128) = '',				-- If blank, then this field is not updated
	@RemoteCampaignField varchar(128) = '',				-- If blank, then this field is not updated
	
	@RemoteStateIgnoreList varchar(128) = '15,100',			-- Do not update MTS_Master entries if the DB State in the remote table is in this list

	@PreviewSql tinyint = 0,								-- If 1, then prints the sql commands but does not execute them
	@DBCountUpdated int = 0 OUTPUT,
	@message varchar(255) = '' OUTPUT
)
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Set @PreviewSql = IsNull(@PreviewSql, 0)
	set @DBCountUpdated = 0
	set @message = ''
	
	declare @SQL nvarchar(2048)
	declare @result int

	set @result = 0
	set @RemoteDescriptionField = IsNull(@RemoteDescriptionField, '')
	set @RemoteOrganismField = IsNull(@RemoteOrganismField, '')
	set @RemoteCampaignField = IsNull(@RemoteCampaignField, '')

	declare @Server varchar(128)
	declare @MTMain varchar(164)

	--------------------------------------------------------
	-- Lookup the ServerName for the given ServerID
	--------------------------------------------------------
	--
	SELECT TOP 1
		@Server = Server_Name
	FROM  T_MTS_Servers
	WHERE Server_ID = @ServerID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 Or @myRowCount <> 1
	begin
		set @message = 'Could not get server name from T_MTS_Servers'
		set @myError = 60000
		goto Done
	end

	-- If @Server is actually this server, then we do not need to prepend table names with the text
	If Lower(@Server) = Lower(@@ServerName)
		Set @MTMain = 'MT_Main.dbo.'
	Else
		Set @MTMain = @Server + '.MT_Main.dbo.'


	If @UpdateTableNames <> 0
	Begin
	
		--------------------------------------------------------
		-- First update any names or servers that do not match
		--------------------------------------------------------
		
		Set @sql = ''
		Set @sql = @sql + ' UPDATE LocalTable'
		Set @sql = @sql + ' SET ' + @LocalNameField + ' = RemoteTable.' + @RemoteNameField + ','
		Set @sql = @sql + '   Server_ID = ' + Convert(varchar(9), @ServerID) + ','
		Set @sql = @sql + '   Last_Affected = GetDate()'
		Set @sql = @sql + ' FROM ' + @LocalTableName + ' AS LocalTable INNER JOIN'
		Set @sql = @sql + ' ' + @MTMain + @RemoteTableName + ' AS RemoteTable ON'
		Set @sql = @sql + '   LocalTable.' + @LocalIDField + ' = RemoteTable.' + @RemoteIDField
		Set @sql = @sql + ' WHERE (LocalTable.' + @LocalNameField + ' <> RemoteTable.' + @RemoteNameField
		Set @sql = @sql + '        OR LocalTable.Server_ID <> ' +  Convert(varchar(9), @ServerID) + ')'
		If @RemoteStateIgnoreList <> ''
			Set @sql = @sql + '   AND RemoteTable.' + @RemoteStateField + ' NOT IN (' + @RemoteStateIgnoreList + ')'

		If @PreviewSql <> 0
			Print @Sql
		Else
		Begin
			EXEC @result = sp_executesql @sql
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @result <> 0
			Begin
				Set @message = 'Error adding new names to local table from remote table: ' + @MTMain + @RemoteTableName

				Set @myError = 60001
				Goto Done
			End
			Else
				Set @DBCountUpdated = @DBCountUpdated + @myRowCount
		End
					
		--------------------------------------------------------
		-- Second add any missing names
		--------------------------------------------------------
		
		Set @sql = ''
		Set @sql = @sql + ' INSERT INTO ' + @LocalTableName + ' (' + @LocalIDField + ', ' + @LocalNameField + ', '
		Set @sql = @sql + '   Server_ID, ' + @LocalStateField + ', Last_Affected, ' + @LocalSchemaVersionField + ')'
		Set @sql = @sql + ' SELECT RemoteTable.' + @RemoteIDField + ', RemoteTable.' + @RemoteNameField + ', '
		Set @sql = @sql +   Convert(varchar(9), @ServerID) + ', RemoteTable.' + @RemoteStateField + ', '
		Set @sql = @sql +   'GetDate(), RemoteTable.' + @RemoteSchemaVersionField
		Set @sql = @sql + ' FROM ' + @MTMain + @RemoteTableName + ' AS RemoteTable '
		Set @sql = @sql + ' WHERE RemoteTable.' + @RemoteNameField + ' NOT IN ('
		Set @sql = @sql +     ' SELECT ' + @LocalNameField + ' FROM ' + @LocalTableName + ')'
		If @RemoteStateIgnoreList <> ''
			Set @sql = @sql + '   AND RemoteTable.' + @RemoteStateField + ' NOT IN (' + @RemoteStateIgnoreList + ')'

		If @PreviewSql <> 0
			Print @Sql
		Else
		Begin
			EXEC @result = sp_executesql @sql
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @result <> 0
			Begin
				Set @message = 'Error updating names in local table to match those in remote table: ' + @MTMain + @RemoteTableName

				Set @myError = 60002
				Goto Done
			End
			Else
				Set @DBCountUpdated = @DBCountUpdated + @myRowCount		
		End
	End
	
	--------------------------------------------------------
	-- Now update mis-matched states or DB Schema Versions
	--------------------------------------------------------
	
	Set @sql = ''
	Set @sql = @sql + ' UPDATE LocalTable'
	Set @sql = @sql + ' SET '
	Set @sql = @sql +      @LocalStateField + ' = RemoteTable.' + @RemoteStateField + ','
	Set @sql = @sql +      @LocalSchemaVersionField + ' = RemoteTable.' + @RemoteSchemaVersionField

	If @RemoteDescriptionField <> ''
		Set @sql = @sql +      ', Description = RemoteTable.' + @RemoteDescriptionField
	
	If @RemoteOrganismField <> ''
		Set @sql = @sql +      ', Organism = RemoteTable.' + @RemoteOrganismField
	
	If @RemoteCampaignField <> ''
		Set @sql = @sql +      ', Campaign = RemoteTable.' + @RemoteCampaignField

	Set @sql = @sql + '    , Last_Affected = GetDate()'
	Set @sql = @sql + ' FROM ' + @LocalTableName + ' AS LocalTable INNER JOIN'
	Set @sql = @sql + ' ' + @MTMain + @RemoteTableName + ' AS RemoteTable ON'
	Set @sql = @sql + '   LocalTable.' + @LocalIDField + ' = RemoteTable.' + @RemoteIDField
	Set @sql = @sql + ' WHERE (LocalTable.' + @LocalStateField + ' <> RemoteTable.' + @RemoteStateField + ' OR '
	Set @sql = @sql +        ' LocalTable.' + @LocalSchemaVersionField + ' <> RemoteTable.' + @RemoteSchemaVersionField

	If @RemoteDescriptionField <> ''
		Set @sql = @sql +      ' OR IsNull(Description,'''') <> IsNull(RemoteTable.' + @RemoteDescriptionField + ','''') '
	
	If @RemoteOrganismField <> ''
		Set @sql = @sql +      ' OR IsNull(Organism,'''') <> IsNull(RemoteTable.' + @RemoteOrganismField + ','''') '
	
	If @RemoteCampaignField <> ''
		Set @sql = @sql +      ' OR IsNull(Campaign,'''') <> IsNull(RemoteTable.' + @RemoteCampaignField + ','''') '

	Set @sql = @sql +          ')'
	
	If @RemoteStateIgnoreList <> ''
		Set @sql = @sql + '   AND RemoteTable.' + @RemoteStateField + ' NOT IN (' + @RemoteStateIgnoreList + ')'

	If @PreviewSql <> 0
		Print @Sql
	Else
	Begin
		EXEC @result = sp_executesql @sql
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount


		If @result <> 0
		Begin
			Set @message = 'Error updating states in local table to match those in remote table: ' + @MTMain + @RemoteTableName

			Set @myError = 60003
			Goto Done
		End
		Else
			Set @DBCountUpdated = @DBCountUpdated + @myRowCount
	End
	
	--------------------------------------------------------
	-- Update Last_Online
	--------------------------------------------------------
	
	Set @sql = ''
	Set @sql = @sql + ' UPDATE LocalTable'
	Set @sql = @sql + ' SET Last_Online = CONVERT(date, GETDATE())'
	Set @sql = @sql + ' FROM ' + @LocalTableName + ' AS LocalTable INNER JOIN'
	Set @sql = @sql + ' ' + @MTMain + @RemoteTableName + ' AS RemoteTable ON'
	Set @sql = @sql + '   LocalTable.' + @LocalIDField + ' = RemoteTable.' + @RemoteIDField
	Set @sql = @sql + ' WHERE RemoteTable.' + @RemoteStateField + ' < 15 AND '
	Set @sql = @sql +       ' IsNull(Last_Online, ''1/1/1990'') <> CONVERT(date, GETDATE())'

	If @PreviewSql <> 0
		Print @Sql
	Else
	Begin
		EXEC @result = sp_executesql @sql
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount


		If @result <> 0
		Begin
			Set @message = 'Error updating Last_Online in local table using remote table: ' + @MTMain + @RemoteTableName

			Set @myError = 60004
			Goto Done
		End
	End
	
Done:
	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--

	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[UpdateDatabaseStatesSingleTable] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateDatabaseStatesSingleTable] TO [MTS_DB_Lite] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[UpdateDatabaseStatesSingleTable] TO [MTUser] AS [dbo]
GO
