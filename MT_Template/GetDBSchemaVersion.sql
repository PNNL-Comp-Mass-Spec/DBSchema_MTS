/****** Object:  StoredProcedure [dbo].[GetDBSchemaVersion] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetDBSchemaVersion
/****************************************************
**
**	Desc: 
**		Returns the schema version for this database
**
**		Return value: integer portion of the DB schema version
**
**	Parameters:
**
**		Auth: mem
**		Date: 09/20/2004
**    
*****************************************************/
(
	@DBSchemaVersion real = 2.0 OUTPUT
)
As
	set nocount on
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @DBSchemaVersionText varchar(64)
						
	Set @DBSchemaVersionText = '2.0'
	
	SELECT @DBSchemaVersionText = DB_Schema_Version
	FROM V_DB_Schema_Version
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	
	If IsNumeric(@DBSchemaVersionText) = 1
		Set @DBSchemaVersion = Convert(real, @DBSchemaVersionText)
	Else
		Set @DBSchemaVersion = 1.0

	
	-- Note that the following will get truncated to an int
	Return @DBSchemaVersion

GO
GRANT EXECUTE ON [dbo].[GetDBSchemaVersion] TO [DMS_SP_User]
GO
GRANT VIEW DEFINITION ON [dbo].[GetDBSchemaVersion] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[GetDBSchemaVersion] TO [MTS_DB_Lite]
GO
