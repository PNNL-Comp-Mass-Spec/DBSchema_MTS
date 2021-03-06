/****** Object:  StoredProcedure [dbo].[GetDatabaseConnectionString] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure dbo.GetDatabaseConnectionString
/****************************************************
** 
**		Desc: **			Returns ADO connection string to database **			given by name
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth: grk
**		Date: 11/12/2001
**    
**		Modifications:
**			12/17/01 mep - added code to retrieve orf
**			database connection strings
**
*****************************************************/
	@databaseName varchar(255),
	@connectionString varchar(1024) output
As
	set nocount on
	
	declare @myError int
	set @myError = 0
	
	set @connectionString = ''

	-- is it in mass tag database table?
	--
	SELECT @connectionString = MTL_Connection_String
	FROM T_MT_Database_List
	WHERE (MTL_Name = @databaseName)
	--
	set @myError = @@error
	--
	if @myError <> 0 return 11
	--
	if @connectionString <> '' return 0
	
	-- is it in peptide database table?
	--
	--SELECT PDB_Connection_String
	SELECT @connectionString = PDB_Connection_String
	FROM T_Peptide_Database_List
	WHERE (PDB_Name = @databaseName)
	--
	set @myError = @@error
	--
	if @myError <> 0 return 11
	--
	if @connectionString <> '' return 0

	--return 22

	-- is it in ORF database table?
	--
	--SELECT ODB_Connection_String
	SELECT @connectionString = ODB_Connection_String
	FROM T_ORF_Database_List
	WHERE (ODB_Name = @databaseName)
	--
	set @myError = @@error
	--
	if @myError <> 0 return 11
	--
	if @connectionString <> '' return 0

	return 22

GO
GRANT EXECUTE ON [dbo].[GetDatabaseConnectionString] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetDatabaseConnectionString] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetDatabaseConnectionString] TO [MTS_DB_Lite] AS [dbo]
GO
