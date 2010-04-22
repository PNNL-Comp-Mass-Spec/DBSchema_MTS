/****** Object:  StoredProcedure [dbo].[SetDBConnectionStrings] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE dbo.SetDBConnectionStrings
/****************************************************
**
**	Desc: 
**
**	Updates the connection strings in T_MT_Database_List,
**  T_Peptide_Database_List, and T_ORF_Database_List
**
**	Parameters:
**
**		Auth: mem
**		Date: 6/21/2005
**
*****************************************************/
	@message varchar(512)='' output
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	set @message = ''

	declare @ServerName varchar(128)
	
	SELECT @ServerName = Convert(varchar(128), SERVERPROPERTY('servername'))

	UPDATE T_MT_Database_List
	SET MTL_Connection_String = 'Provider=sqloledb;Data Source=' + @ServerName + ';Initial Catalog=' + MTL_Name + ';User ID=mtuser;Password=mt4fun', 
		MTL_NetSQL_Conn_String = 'Server=' + @ServerName + ';database=' + MTL_Name + ';uid=mtuser;Password=mt4fun', 
		MTL_NetOleDB_Conn_String = 'Provider=sqloledb;Data Source=' + @ServerName + ';Initial Catalog=' + MTL_Name + ';User ID=mtuser;Password=mt4fun'
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	Set @message = 'Updated ' + convert(varchar(19), @myRowCount) + ' rows in T_MT_Database_List'

	UPDATE T_Peptide_Database_List
	SET PDB_Connection_String = 'Provider=sqloledb;Data Source=' + @ServerName + ';Initial Catalog=' + PDB_Name + ';User ID=mtuser;Password=mt4fun', 
		PDB_NetSQL_Conn_String = 'Server=' + @ServerName + ';database=' + PDB_Name + ';uid=mtuser;Password=mt4fun', 
		PDB_NetOleDB_Conn_String = 'Provider=sqloledb;Data Source=' + @ServerName + ';Initial Catalog=' + PDB_Name + ';User ID=mtuser;Password=mt4fun'
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	Set @message = @message + '; Updated ' + convert(varchar(19), @myRowCount) + ' rows in T_Peptide_Database_List'

	UPDATE T_ORF_Database_List
	SET ODB_Connection_String = 'Provider=sqloledb;Data Source=' + @ServerName + ';Initial Catalog=' + ODB_Name + ';User ID=mtuser;Password=mt4fun', 
		ODB_NetSQL_Conn_String = 'Server=' + @ServerName + ';database=' + ODB_Name + ';uid=mtuser;Password=mt4fun', 
		ODB_NetOleDB_Conn_String = 'Provider=sqloledb;Data Source=' + @ServerName + ';Initial Catalog=' + ODB_Name + ';User ID=mtuser;Password=mt4fun'
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	Set @message = @message + '; Updated ' + convert(varchar(19), @myRowCount) + ' rows in T_ORF_Database_List'
   
      
   	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	SELECT @message as TheMessage
	
	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[SetDBConnectionStrings] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[SetDBConnectionStrings] TO [MTS_DB_Lite] AS [dbo]
GO
