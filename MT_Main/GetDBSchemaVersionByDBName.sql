/****** Object:  StoredProcedure [dbo].[GetDBSchemaVersionByDBName] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetDBSchemaVersionByDBName
/****************************************************
** 
**	Desc:	Calls GetDBSchemaVersion in the given database (must be located on this server)
**
**			Use Prism_IFC.dbo.GetDBSchemaVersionByDBName() for databases that may or may not be on this server
**
**	Return value: integer portion of the DB schema version
** 
** 
**	Auth:	mem
**	Date:	08/20/2004
**			11/23/2005 mem - Added brackets around @DBName as needed to allow for DBs with dashes in the name
**    
*****************************************************/
(
	@DBName varchar(128) = '',
	@DBSchemaVersion real = 1.0 output
)
AS

	Declare @SPToExec varchar(512)
	Declare @myError int
	
	-- Lookup the DBSchemaVersion by calling GetDBSchemaVersion in @DBName
	Set @SPToExec = '[' + @DBName + '].dbo.GetDBSchemaVersion'
	Set @DBSchemaVersion = 1.0
	Set @myError = 0
	
	Exec @myError = @SPToExec @DBSchemaVersion output
	
	-- Note that the following will get truncated to an int
	Return @DBSchemaVersion


GO
GRANT EXECUTE ON [dbo].[GetDBSchemaVersionByDBName] TO [DMS_SP_User]
GO
