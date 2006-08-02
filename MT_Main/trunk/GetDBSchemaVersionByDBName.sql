SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetDBSchemaVersionByDBName]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetDBSchemaVersionByDBName]
GO

CREATE PROCEDURE dbo.GetDBSchemaVersionByDBName
/****************************************************
** 
**		Desc: 
**		Calls GetDBSchemaVersion in the given database
**
**		Return value: integer portion of the DB schema version
** 
** 
**		Auth: mem
**		Date: 08/20/2004
**			  11/23/2005 mem - Added brackets around @DBName as needed to allow for DBs with dashes in the name
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
	Set @SPToExec = '[' + @DBName + ']..GetDBSchemaVersion'
	Set @DBSchemaVersion = 1.0
	Set @myError = 0
	
	Exec @myError = @SPToExec @DBSchemaVersion output
	
	-- Note that the following will get truncated to an int
	Return @DBSchemaVersion

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetDBSchemaVersionByDBName]  TO [DMS_SP_User]
GO

