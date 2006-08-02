SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetDBLocation]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetDBLocation]
GO

CREATE PROCEDURE dbo.GetDBLocation
/****************************************************
**
**	Desc: Given a DB Name, returns the databases's
**		  server name and full path to the database
**		  Also returns the DB ID and DB type (see description below)
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 11/13/2004 
**			  11/23/2005 mem - Added brackets around @DBName as needed to allow for DBs with dashes in the name
**							 - Note that @DBPath will have square brackets around the database name; necessary for databases with dashes or other non-alphanumeric symbols
**    
*****************************************************/
	@DBName varchar(128) = 'MT_BSA_P171',
	@DBType tinyint = 0 output,		-- If 0, then will check all T_MTS tables to find DB; 
									-- If 1, then assumes a PMT tag DB (MT_), 
									-- If 2, then assumes a Peptide DB (PT_), 
									-- If 3, then assumes a Protein DB (ORF_), 
									-- If 4, then assumes a UMC DB (UMC_)
	@serverName varchar(64) = '' output,
	@DBPath varchar(256) = '' output,		-- Path to the DB; if on this server, then simply @DBName; otherwise, ServerName.DBName
	@DBID int = 0 output,
	@message varchar(512) = '' output
AS
	SET NOCOUNT ON
	 
	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @DBType = IsNull(@DBType,0)
	set @serverName = ''
	set @DBPath = ''
	set @DBID = 0
	set @message = ''
		
	declare @DBTypeCurrent tinyint
	declare @ServerID int

	If @DBType >= 1 and @DBType <= 4
		Set @DBTypeCurrent = @DBType
	Else
	Begin
		Set @DBTypeCurrent = 1
		Set @DBType = 0
	End

	Set @ServerID = 0
	
	While @DBTypeCurrent <= 4
	Begin
		If @DBTypeCurrent = 1
		Begin
			-- Look for @DBName in T_MTS_MT_DBs
			SELECT @ServerID = Server_ID, @DBID = MT_DB_ID
			FROM T_MTS_MT_DBs
			WHERE MT_DB_Name = @DBName
		End
		Else
		  If @DBTypeCurrent = 2
		Begin
			-- Look for @DBName in T_MTS_Peptide_DBs
			SELECT @ServerID = Server_ID, @DBID = Peptide_DB_ID
			FROM T_MTS_Peptide_DBs
			WHERE Peptide_DB_Name = @DBName
		End
		Else
		  If @DBTypeCurrent = 3
		Begin
			-- Look for @DBName in T_MTS_Protein_DBs
			SELECT @ServerID = Server_ID, @DBID = Protein_DB_ID
			FROM T_MTS_Protein_DBs
			WHERE Protein_DB_Name = @DBName
		End
		Else
		  If @DBTypeCurrent = 4
		Begin
			-- Look for @DBName in T_MTS_UMC_DBs
			SELECT @ServerID = Server_ID, @DBID = UMC_DB_ID
			FROM T_MTS_UMC_DBs
			WHERE UMC_DB_Name = @DBName
		End
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Error looking for database named ' + @DBName + ' in the MTS tables'
			goto Done
		end
		
		if @myRowCount > 0
		Begin
			Set @DBType = @DBTypeCurrent
			
			-- Lookup the server name using the ID
			SELECT @serverName = Server_Name
			FROM T_MTS_Servers
			WHERE Server_ID = @ServerID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @myRowCount > 0
			Begin
				If Lower(@@ServerName) = Lower(@serverName)
					Set @DBPath = '[' + @DBName + ']'
				Else
					Set @DBPath = @serverName + '.[' + @DBName + ']'
			End

			-- Set this to 100 so that the While loop is exited
			Set @DBTypeCurrent = 100
		End
		Else
		Begin
			If @DBType = 0
				Set @DBTypeCurrent = @DBTypeCurrent + 1
			Else
				-- Set this to 100 so that the While loop is exited
				Set @DBTypeCurrent = 100
		End		
	End
	
	If Len(@DBPath) = 0
		Set @message = 'Database not found: ' + @DBName
		
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetDBLocation]  TO [DMS_SP_User]
GO

GRANT  EXECUTE  ON [dbo].[GetDBLocation]  TO [MTUser]
GO

GRANT  EXECUTE  ON [dbo].[GetDBLocation]  TO [pogo\MTS_DB_Dev]
GO

GRANT  EXECUTE  ON [dbo].[GetDBLocation]  TO [MTS_DB_Lite]
GO

