/****** Object:  StoredProcedure [dbo].[GetExportFilterIDsForPeptideDB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetExportFilterIDsForPeptideDB
/****************************************************
**
**	Desc: 
**	Returns list of MTDB Export filter IDs for the given Peptide Database.
**  This is useful when designing custom queries that filter the entries in
**  T_Peptides to only contain those with a match to a given filter ID (using T_Peptide_Filter_Flags)
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @DBName				-- Peptide database name
**	  @message				-- Status/error message output
**
**		Auth: mem
**		Date: 07/16/2005
**			  11/23/2005 mem - Added brackets around @DBName as needed to allow for DBs with dashes in the name
**
*****************************************************/
	@DBName varchar(128) = '',
	@message varchar(512) = '' output
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''
	
	---------------------------------------------------
	-- Validate that DB exists on this server, determine its type,
	-- and look up its schema version
	---------------------------------------------------

	Declare @DBType tinyint				-- 1 if PMT Tag DB, 2 if Peptide DB
	Declare @DBSchemaVersion real
	
	Set @DBType = 0
	Set @DBSchemaVersion = 1
	
	Exec @myError = GetDBTypeAndSchemaVersion @DBName, @DBType OUTPUT, @DBSchemaVersion OUTPUT, @message = @message OUTPUT

	-- Make sure the type is 2 and that no errors occurred
	If @DBType = 0 Or @myError <> 0
	Begin
		If @myError = 0
			Set @myError = 20000

		If Len(@message) = 0
			Set @message = 'Database not found on this server: ' + @DBName
		Goto Done
	End
	Else
	If @DBType <> 2
	Begin
		Set @myError = 20001
		Set @message = 'Database ' + @DBName + ' is not a Peptide DB and is therefore not appropriate for this procedure'
		Goto Done
	End
	Else
	If @DBSchemaVersion <= 1
	Begin
		Set @myError = 20002
		Set @message = 'Database ' + @DBName + ' has a DB Schema Version less than 2 and is therefore not supported by this procedure'
		Goto Done
	End

	---------------------------------------------------
	-- build the sql query to get the data
	---------------------------------------------------
	declare @S varchar(2048)

	Set @S = ''
	Set @S = @S + ' SELECT Filter_Set_ID, Filter_Set_Name, Filter_Set_Description'
	Set @S = @S + ' FROM [' + @DBName + ']..V_Filter_Set_Overview'
	Set @S = @S + ' WHERE Filter_Type_ID = 2'
	Set @S = @S + ' ORDER BY Filter_Set_ID'
	
	-- Obtain the data
	Exec (@S)
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows'
	
	Exec PostUsageLogEntry 'GetExportFilterIDsForPeptideDB', @DBName, @UsageMessage
	
Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[GetExportFilterIDsForPeptideDB] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetExportFilterIDsForPeptideDB] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetExportFilterIDsForPeptideDB] TO [MTS_DB_Lite] AS [dbo]
GO
