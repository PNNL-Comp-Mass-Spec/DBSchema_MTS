/****** Object:  StoredProcedure [dbo].[GetDBSchemaVersionByDBName] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetDBSchemaVersionByDBName
/****************************************************
** 
**	Desc: Calls GetDBSchemaVersion in the given database
**
**	Return value: integer portion of the DB schema version
** 
** 
**	Auth:	mem
**	Date:	08/20/2004
**			12/06/2004 mem - Updated to call Pogo.MTS_Master.dbo.GetDBSchemaVersionByDBName
**    
*****************************************************/
(
	@DBName varchar(128) = '',
	@DBSchemaVersion real = 1.0 output,
	@message varchar(256) = '' output
)
AS

	Declare @myError int
	Set @myError = 0

	Set @DBSchemaVersion = 1.0
	Set @message = ''

	-- Note that GetDBSchemaVersionByDBName returns the integer portion of the schema version, and not an error code
	Exec Pogo.MTS_Master.dbo.GetDBSchemaVersionByDBName @DBName, @DBSchemaVersion = @DBSchemaVersion OUTPUT, @message = @message OUTPUT
	Set @myError = @@Error
	
	If @myError <> 0
	Begin
		Set @message = 'Error calling GetDBSchemaVersionByDBName in MTS_Master; error code = ' + convert(varchar(12), @myError)
		Set @DBSchemaVersion = IsNull(@DBSchemaVersion, 1)
	End
	
	-- Note that the following will get truncated to an int
	Return IsNull(@DBSchemaVersion, 1)


GO
GRANT EXECUTE ON [dbo].[GetDBSchemaVersionByDBName] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetDBSchemaVersionByDBName] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetDBSchemaVersionByDBName] TO [MTS_DB_Lite] AS [dbo]
GO
