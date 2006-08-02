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
**	Desc:	Get the name of the peptide DB(s) and ORF DB(s)
**			that are assigned to the given mass tag DB.
**
**			Note: This SP is used by SPs in MT_Main and Prism_IFC
**
**	Return values: 0: success, otherwise, error code
** 
** 
**	Auth:	grk
**	Date:	04/16/2004
**			09/20/2004 mem - Added support for MTDB Schema version 2
**			11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**			07/23/2006 mem - Added parameters @PeptideDBList and @ProteinDBList that return all DBs listed in T_Process_Config for the given database
**    
*****************************************************/
(
	@MTDBName varchar(128) = '',
	@PeptideDBName varchar(128) = '' output,		-- Peptide DB defined in T_Process_Config; if more than one DB is listed, then this is the first one alphabetically
	@ProteinDBName varchar(128) = '' output,
	@DBSchemaVersionOverride real = 0,				-- If greater than 0, then does not call GetDBSchemaVersionByDBName
	@PeptideDBList varchar(1024) = '' output,		-- All Peptide DBs defined in T_Process_Config, separating each with a comma (does not include a comma after the final DB)
	@ProteinDBList varchar(1024) = '' output		-- All Peptide DBs defined in T_Process_Config, separating each with a comma (does not include a comma after the final DB)
)	
AS
	SET NOCOUNT ON

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	declare @DBSchemaVersion real
	Set @DBSchemaVersion = 1.0
	
	-- Clear the output parameters
	set @PeptideDBName = ''
	set @ProteinDBName = ''
	set @PeptideDBList = ''
	set @ProteinDBList = ''
	

	-- set up base SQL query
	--
	declare @PepSql nvarchar(1024)
	declare @ProSql nvarchar(1024)

	If IsNull(@DBSchemaVersionOverride, 0) = 0
		Exec GetDBSchemaVersionByDBName @MTDBName, @DBSchemaVersion output
	Else
		Set @DBSchemaVersion = @DBSchemaVersionOverride
		
	
	If @DBSchemaVersion < 2
	Begin
		set @PepSql = ''
		set @PepSql = @PepSql + ' SELECT @PeptideDBName = Peptide_DB_Name,'
		set @PepSql = @PepSql +        ' @ProteinDBName = ORF_DB_Name'
		set @PepSql = @PepSql + ' FROM DATABASE.dbo.T_External_Databases'

		set @PepSql = REPLACE(@PepSql, 'DATABASE.dbo.', '[' + @MTDBName + '].dbo.')

		exec sp_executesql @PepSql, N'@PeptideDBName varchar(128) output, @ProteinDBName varchar(128) output', @PeptideDBName = @PeptideDBName output, @ProteinDBName = @ProteinDBName output
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

	End
	Else
	Begin
		set @PepSql = ''
		set @PepSql = @PepSql + ' SELECT TOP 1 @PeptideDBName = Value'
		set @PepSql = @PepSql + ' FROM DATABASE.dbo.T_Process_Config'
		set @PepSql = @PepSql + ' WHERE Name = ''Peptide_DB_Name'''
		set @PepSql = @PepSql + ' ORDER BY Value'

		set @ProSql = ''
		set @ProSql = @ProSql + ' SELECT TOP 1 @ProteinDBName = Value'
		set @ProSql = @ProSql + ' FROM DATABASE.dbo.T_Process_Config'
		set @ProSql = @ProSql + ' WHERE Name = ''Protein_DB_Name'''
		set @ProSql = @ProSql + ' ORDER BY Value'

		set @PepSql = REPLACE(@PepSql, 'DATABASE.dbo.', '[' + @MTDBName + '].dbo.')
		set @ProSql = REPLACE(@ProSql, 'DATABASE.dbo.', '[' + @MTDBName + '].dbo.')


		exec sp_executesql @PepSql, N'@PeptideDBName varchar(128) output', @PeptideDBName = @PeptideDBName output
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount


		exec sp_executesql @ProSql, N'@ProteinDBName varchar(128) output', @ProteinDBName = @ProteinDBName output
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount


		set @PepSql = ''
		set @PepSql = @PepSql + ' SELECT @PeptideDBList = @PeptideDBList + Value + '','''
		set @PepSql = @PepSql + ' FROM DATABASE.dbo.T_Process_Config'
		set @PepSql = @PepSql + ' WHERE Name = ''Peptide_DB_Name'''
		set @PepSql = @PepSql + ' ORDER BY Value'

		set @ProSql = ''
		set @ProSql = @ProSql + ' SELECT @ProteinDBList = @ProteinDBList + Value + '','''
		set @ProSql = @ProSql + ' FROM DATABASE.dbo.T_Process_Config'
		set @ProSql = @ProSql + ' WHERE Name = ''Protein_DB_Name'''
		set @ProSql = @ProSql + ' ORDER BY Value'

		set @PepSql = REPLACE(@PepSql, 'DATABASE.dbo.', '[' + @MTDBName + '].dbo.')
		set @ProSql = REPLACE(@ProSql, 'DATABASE.dbo.', '[' + @MTDBName + '].dbo.')

		exec sp_executesql @PepSql, N'@PeptideDBList varchar(128) output', @PeptideDBList = @PeptideDBList output
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		-- Remove the trailing comma from @PeptideDBList
		If @myRowCount > 0
			Set @PeptideDBList = Left(@PeptideDBList, Len(@PeptideDBList)-1)


		exec sp_executesql @ProSql, N'@ProteinDBList varchar(128) output', @ProteinDBList = @ProteinDBList output
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		-- Remove the trailing comma from @ProteinDBList
		If @myRowCount > 0
			Set @ProteinDBList = Left(@ProteinDBList, Len(@ProteinDBList)-1)

	End

Done:		
	RETURN @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetMTAssignedDBs]  TO [DMS_SP_User]
GO

