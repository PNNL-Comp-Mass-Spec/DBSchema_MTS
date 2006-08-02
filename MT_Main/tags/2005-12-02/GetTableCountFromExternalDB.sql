SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetTableCountFromExternalDB]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetTableCountFromExternalDB]
GO

CREATE PROCEDURE GetTableCountFromExternalDB
/****************************************************
** 
**		Desc: 
**
**		Return values: 0: success, otherwise, error code
** 
** 
**		Auth: grk
**		Date: 02/19/2003
**			  11/23/2005 mem - Added brackets around @dbName as needed to allow for DBs with dashes in the name
**    
*****************************************************/
	@dbName varchar(128) = 'PT_None_A67',
	@tableName varchar(64) = 'T_Sequence',
	@count int output
AS
	SET NOCOUNT ON

	-- set up base SQL query
	--
	declare @myCount int
	declare @S nvarchar(1024)

	set @S = ''
	set @S = @S + ' SELECT @myCount = i.rows'
	set @S = @S + ' FROM DATABASE..sysobjects o'
	set @S = @S + ' INNER JOIN DATABASE..sysindexes i ON (o.id = i.id)'
	set @S = @S + ' WHERE o.type = ''u'' AND i.indid < 2'
	set @S = @S +   ' AND o.name = ''TTT'''
	
	set @S = REPLACE(@S, 'DATABASE..', '[' + @dbName + ']..')
	set @S = REPLACE(@S, 'TTT', @tableName)

	exec sp_executesql @S, N'@myCount int output', @myCount = @myCount output
	--
	set @count = @myCount

	RETURN 0

			
			 
			
			
			
			

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetTableCountFromExternalDB]  TO [DMS_SP_User]
GO

