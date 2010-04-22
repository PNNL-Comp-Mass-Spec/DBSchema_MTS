/****** Object:  StoredProcedure [dbo].[GetDatabaseConnectionStringEx] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure dbo.GetDatabaseConnectionStringEx
/****************************************************
** 
**		Desc: **			Returns connection string to database **			given by name and connection type
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth: grk
**		Date: 6/12/2002
**    
**
*****************************************************/
	@databaseName varchar(255),
	@connectionString varchar(1024) output,
	@connectionType varchar(64) = 'ADO' -- 'NetSQL', 'NetOleDB'
As
	set nocount on
	
	declare @myError int
	set @myError = 0
	
	declare @myRowcount int
	
	set @connectionString = ''
	
	declare @ADOConnString varchar(1024)
	declare @NetSqlConnString varchar(1024)
	declare @NetOleDBConnString varchar(1024)

	-- is it in mass tag database table?
	--
	SELECT 
	 @ADOConnString = MTL_Connection_String,
	 @NetSqlConnString = MTL_NetSQL_Conn_String, 
	 @NetOleDBConnString = MTL_NetOleDB_Conn_String
	FROM T_MT_Database_List
	WHERE (MTL_Name = @databaseName)
	--
	select @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 return 11
	--
	if @myRowCount > 0 goto Found
	
	
	-- is it in peptide database table?
	--
	--SELECT PDB_Connection_String
	SELECT 
	 @ADOConnString = PDB_Connection_String,
	 @NetSqlConnString = PDB_NetSQL_Conn_String, 
	 @NetOleDBConnString = PDB_NetOleDB_Conn_String
	FROM T_Peptide_Database_List
	WHERE (PDB_Name = @databaseName)
	--
	select @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 return 11
	--
	if @myRowCount > 0 goto Found

	-- is it in ORF database table?
	--
	--SELECT ODB_Connection_String
	SELECT
	 @ADOConnString = ODB_Connection_String,
	 @NetSqlConnString = ODB_NetSQL_Conn_String, 
	 @NetOleDBConnString = ODB_NetOleDB_Conn_String
	FROM T_ORF_Database_List
	WHERE (ODB_Name = @databaseName)
	--
	select @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 return 11
	--
	if @myRowCount > 0 goto Found
	
	return 0

Found:
	-- get appropriate variation of connection string
	--
	if @connectionType = 'NetSQL'
	begin
		set @connectionString = @NetSqlConnString
	end
	else
	if @connectionType = 'NetOleDB'
	begin
		set @connectionString = @NetOleDBConnString
	end
	else
	begin
		set @connectionString = @ADOConnString
	end


	return 22

GO
GRANT EXECUTE ON [dbo].[GetDatabaseConnectionStringEx] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetDatabaseConnectionStringEx] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetDatabaseConnectionStringEx] TO [MTS_DB_Lite] AS [dbo]
GO
