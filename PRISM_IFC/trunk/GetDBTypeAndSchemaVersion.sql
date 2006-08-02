SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetDBTypeAndSchemaVersion]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetDBTypeAndSchemaVersion]
GO


CREATE PROCEDURE dbo.GetDBTypeAndSchemaVersion
/****************************************************
** 
**	Desc:	Looks for the database named @DBName in MT_Main on this server.
**			Returns the database type code (0 if not found) and DB schema version
**
**		Note that GetDBLocation in MTS_Master is similar to this SP, but that procedure
**		uses the information from MTS_Master rather than MT_Main on this server.  Also,
**		this procedure polls the database directly to obtain the schema version, rather
**		than using GetDBSchemaVersionByDBName, which uses MTS_Master..GetDBSchemaVersionByDBName
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	07/16/2005
**			11/23/2005 mem - Added brackets around @DBName as needed to allow for DBs with dashes in the name
**			07/25/2006 mem - Now excluding databases in state 15 or state 100
**    
*****************************************************/
(
	@DBName varchar(128) = '',
	@DBType tinyint = 0 output,		-- 0 If unknown, 
									-- 1 If a PMT tag DB (MT_),
									-- 2 If a Peptide DB (PT_),
									-- 3 If a Protein DB (ORF_),
									-- 4 If a UMC DB (UMC_)
	@DBSchemaVersion real = 1.0 output,
	@DBID int = 0 output,
	@message varchar(256) = '' output
)
AS

	Set NOCOUNT ON
	 
	Declare @myRowCount int	
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Set @DBSchemaVersion = 1.0
	Set @DBID = 0
	Set @message = ''
		
	Declare @DBTypeCurrent tinyint
	
	If Len(IsNull(@DBName, '')) = 0
	Begin
		Set @message = 'Error: database name not provided'
		Goto Done
	End
	
	Set @DBTypeCurrent = 1
	Set @DBType = 0
	
	While @DBTypeCurrent <= 4
	Begin
		If @DBTypeCurrent = 1
		Begin
			-- Look for @DBName in T_MT_Database_List
			SELECT @DBID = MTL_ID
			FROM MT_Main.dbo.T_MT_Database_List
			WHERE MTL_Name = @DBName AND
				  MTL_State NOT IN (15, 100)
		End
		Else
		  If @DBTypeCurrent = 2
		Begin
			-- Look for @DBName in T_Peptide_Database_List
			SELECT @DBID = PDB_ID
			FROM MT_Main.dbo.T_Peptide_Database_List
			WHERE PDB_Name = @DBName AND
				  PDB_State NOT IN (15, 100)
		End
		Else
		  If @DBTypeCurrent = 3
		Begin
			-- Look for @DBName in T_ORF_Database_List
			SELECT @DBID = ODB_ID
			FROM MT_Main.dbo.T_ORF_Database_List
			WHERE ODB_Name = @DBName AND
				  ODB_State NOT IN (15, 100)
		End
		Else
		  If @DBTypeCurrent = 4
		Begin
			-- Look for @DBName in T_UMC_Database_List
			SELECT @DBID = UDB_ID
			FROM MT_Main.dbo.T_UMC_Database_List
			WHERE UDB_Name = @DBName AND
				  UDB_State NOT IN (15, 100)
		End
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0
		Begin
			Set @message = 'Error looking for database named ' + @DBName + ' in MT_Main; error code = ' + convert(varchar(12), @myError)
			goto Done
		End
		
		If @myRowCount > 0
		Begin
			Set @DBType = @DBTypeCurrent
		
			-- Set this to 100 so that the While loop is exited
			Set @DBTypeCurrent = 100
		End
		Else
		Begin
			Set @DBTypeCurrent = @DBTypeCurrent + 1
		End		
	End
	
	If @DBType > 0
	Begin
		-- Match was found; now look up the Schema version by calling GetDBSchemaVersion in @DBName
		-- Note that GetDBSchemaVersion returns the integer portion of the schema version, and not an error code
		Declare @SPToExec varchar(256)
		Set @SPToExec = '[' + @DBName + '].dbo.GetDBSchemaVersion'
		
		Exec @SPToExec @DBSchemaVersion output
		Set @myError = @@Error
		
		If @myError <> 0
		Begin
			Set @message = 'Error calling SP ' + @SPToExec + '; error code = ' + convert(varchar(12), @myError)
			Set @DBSchemaVersion = IsNull(@DBSchemaVersion, 1)
		End
			
	End
	Else
	Begin
		Set @message = 'Error, database not found on this server: ' + @DBName
	End
	
Done:
	Return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetDBTypeAndSchemaVersion]  TO [DMS_SP_User]
GO

