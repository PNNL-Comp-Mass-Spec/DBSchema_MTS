SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetDBSchemaVersion]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetDBSchemaVersion]
GO


CREATE PROCEDURE dbo.GetDBSchemaVersion
/****************************************************
**
**	Desc: 
**		Returns the schema version for this database
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 09/20/2004
**    
*****************************************************/
(
	@DBSchemaVersion real = 1.0 OUTPUT
)
As
	set nocount on
	
	Set @DBSchemaVersion = 1.0
	
	-- Note that the following will get truncated to an int
	Return @DBSchemaVersion



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetDBSchemaVersion]  TO [DMS_SP_USER]
GO

