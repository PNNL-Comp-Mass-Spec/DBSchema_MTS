SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetMTAssignedDBs]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetMTAssignedDBs]
GO

CREATE PROCEDURE GetMTAssignedDBs
/****************************************************
** 
**		Desc: 
**		Get the name of the peptide DB and ORF DB
**      that are assigned to the given mass tag DB.
**		This SP is used by SPs in Prism_IFC
**
**		Return values: 0: success, otherwise, error code
** 
** 
**		Auth: grk
**		Date: 04/16/2004
**			  09/20/2004 mem - Added support for MTDB Schema version 2
**			  11/23/2005 mem - Added brackets around @mtDBName as needed to allow for DBs with dashes in the name
**    
*****************************************************/
	@mtDBName varchar(128) = '',
	@peptideDBName varchar(128) output,
	@proteinDBName varchar(128) output,
	@DBSchemaVersionOverride real = 0		-- If greater than 0, then does not call GetDBSchemaVersionByDBName
AS
	SET NOCOUNT ON

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	declare @DBSchemaVersion real
	Set @DBSchemaVersion = 1.0
	
	set @peptideDBName = ''
	set @proteinDBName = ''

	-- set up base SQL query
	--
	declare @SQL nvarchar(1024)

	If @DBSchemaVersionOverride = 0
		Exec GetDBSchemaVersionByDBName @mtDBName, @DBSchemaVersion output
	Else
		Set @DBSchemaVersion = @DBSchemaVersionOverride
		
	
	If @DBSchemaVersion < 2
	Begin
		set @SQL = ''
		set @SQL = @SQL + 'SELECT '
		set @SQL = @SQL + '@peptideDBName = Peptide_DB_Name, '
		set @SQL = @SQL + '@proteinDBName = ORF_DB_Name '
		set @SQL = @SQL + 'FROM DATABASE..T_External_Databases '
	End
	Else
	Begin
		set @SQL = ''
		set @SQL = @SQL + 'SELECT '
		set @SQL = @SQL + '@peptideDBName = Peptide_DB_Name, '
		set @SQL = @SQL + '@proteinDBName = Protein_DB_Name '
		set @SQL = @SQL + 'FROM DATABASE..V_External_Databases '
	End

	set @SQL = REPLACE(@SQL, 'DATABASE..', '[' + @mtDBName + ']..')

	exec sp_executesql @SQL, N'@peptideDBName varchar(128) output, @proteinDBName varchar(128) output', @peptideDBName = @peptideDBName output, @proteinDBName = @proteinDBName output
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
		
	RETURN @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetMTAssignedDBs]  TO [DMS_SP_User]
GO

