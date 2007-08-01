/****** Object:  StoredProcedure [dbo].[GetDBSchemaVersionByDBName] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetDBSchemaVersionByDBName
/****************************************************
** 
**		Desc: 
**		Calls GetDBSchemaVersion in the given database
**
**		Return values: 0: success, otherwise, error code
** 
** 
**		Auth: mem
**		Date: 8/20/2004
**			  12/06/2004 mem - Ported to MTS_Master
**			  07/16/2005 mem - Now checking for errors after calling GetDBSchemaVersion in @DBName
**			  11/23/2005 mem - Added note concerning square brackets in @DBPath
**    
*****************************************************/
(
	@DBName varchar(128) = '',
	@DBSchemaVersion real = 1.0 output,
	@message varchar(256) = '' output
)
AS

	Declare @SPToExec varchar(512)
	Declare @myError int
	
	Declare @serverName varchar(64)
	Declare @DBPath varchar(256)
	
	Set @DBSchemaVersion = 1.0
	Set @message = ''

	Set @myError = 0
	Set @DBPath = ''

	-- Determine the appropriate server for the database
	-- Note that @DBPath will have square brackets around the database name; necessary for databases with dashes or other non-alphanumeric symbols
	Exec @myError = GetDBLocation @DBName, 0, @serverName = @serverName OUTPUT, @DBPath = @DBPath OUTPUT
	If @myError <> 0
	Begin
		Set @message = 'Error calling GetDBLocation: ' + convert(varchar(12), @myError)
		Goto Done
	End
	
	If Len(IsNull(@DBPath, '')) = 0
	Begin
		Set @message = 'Database not found: ' + @DBName
		Goto Done
	End
	
	-- Lookup the DBSchemaVersion by calling GetDBSchemaVersion in @DBPath
	-- Note that GetDBSchemaVersion returns the integer portion of the schema version, and not an error code
	Set @SPToExec = @DBPath + '.dbo.GetDBSchemaVersion'
	Exec @SPToExec @DBSchemaVersion output
	Set @myError = @@Error
	
	If @myError <> 0
	Begin
		Set @message = 'Error calling SP ' + @SPToExec + '; error code = ' + convert(varchar(12), @myError)
		Set @DBSchemaVersion = IsNull(@DBSchemaVersion, 1)
	End

Done:
	If Len(@message) > 0
		Select @message

	Return @myError

GO
GRANT EXECUTE ON [dbo].[GetDBSchemaVersionByDBName] TO [DMS_SP_User]
GO
GRANT EXECUTE ON [dbo].[GetDBSchemaVersionByDBName] TO [MTS_DB_Lite]
GO
GRANT EXECUTE ON [dbo].[GetDBSchemaVersionByDBName] TO [MTUser]
GO
GRANT EXECUTE ON [dbo].[GetDBSchemaVersionByDBName] TO [pogo\MTS_DB_Dev]
GO
