/****** Object:  StoredProcedure [dbo].[GetDBLocation] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetDBLocation
/****************************************************
**
**	Desc: Given a DB Name, returns the databases's
**			server name and full path to the database
**		  Also returns the DB ID and DB type (see description below)
**		  If the DB Name contains the % sign wildcard, then returns the first
**			matching database (checking in the order given by T_MTS_DB_Types)
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	11/13/2004 
**			11/23/2005 mem - Added brackets around @DBName as needed to allow for DBs with dashes in the name
**						   - Note that @DBPath will have square brackets around the database name; necessary for databases with dashes or other non-alphanumeric symbols
**			02/23/2006 mem - Added support for QCT databases
**			07/25/2006 mem - Added parameters @IncludeDeleted and @CallingServerName
**    
*****************************************************/
(
	@DBName varchar(128) = 'MT_BSA_P171',
	@DBType tinyint = 0 output,		-- If 0, then will check all T_MTS tables to find DB; 
									-- If 1, then assumes a PMT tag DB (MT_), 
									-- If 2, then assumes a Peptide DB (PT_), 
									-- If 3, then assumes a Protein DB (ORF_), 
									-- If 4, then assumes a UMC DB (UMC_)
									-- If 5, then assumes a QC Trends DB (QCT_)
	@serverName varchar(64) = '' output,
	@DBPath varchar(256) = '' output,		-- Path to the DB; if on server @CallingServerName, then simply @DBName; otherwise, ServerName.DBName
	@DBID int = 0 output,
	@message varchar(512) = '' output,
	@IncludeDeleted tinyint = 0,
	@CallingServerName varchar(64) = ''		-- If blank, or if doesn't match @serverName, then includes @serverName in @DBPath
)
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
	
	set @IncludeDeleted = IsNull(@IncludeDeleted, 0)
	set @CallingServerName = IsNull(@CallingServerName, '')
		
	declare @DBTypeCurrent tinyint
	declare @ServerID int
	declare @DBNameOfficial varchar(128)
	declare @WildcardMatch tinyint
	Set @ServerID = 0
	
	If @DBType >= 1 and @DBType <= 5
		Set @DBTypeCurrent = @DBType
	Else
	Begin
		Set @DBTypeCurrent = 1
		Set @DBType = 0
	End

	
	If CharIndex('%', @DBName) > 0
		Set @WildcardMatch = 1
	Else
		Set @WildcardMatch = 0
		
	While @DBTypeCurrent <= 5
	Begin
		If @WildcardMatch = 0
		Begin
			-- Require an exact match
			If @DBTypeCurrent = 1
			Begin
				-- Look for @DBName in T_MTS_MT_DBs
				SELECT	@ServerID = Server_ID, @DBID = MT_DB_ID, 
						@DBNameOfficial = MT_DB_Name
				FROM T_MTS_MT_DBs
				WHERE MT_DB_Name = @DBName AND
					  (@IncludeDeleted <> 0 OR State_ID <> 100)
			End
			Else
			If @DBTypeCurrent = 2
			Begin
				-- Look for @DBName in T_MTS_Peptide_DBs
				SELECT	@ServerID = Server_ID, @DBID = Peptide_DB_ID, 
						@DBNameOfficial = Peptide_DB_Name
				FROM T_MTS_Peptide_DBs
				WHERE Peptide_DB_Name = @DBName AND
					  (@IncludeDeleted <> 0 OR State_ID <> 100)
			End
			Else
			If @DBTypeCurrent = 3
			Begin
				-- Look for @DBName in T_MTS_Protein_DBs
				SELECT	@ServerID = Server_ID, @DBID = Protein_DB_ID, 
						@DBNameOfficial = Protein_DB_Name
				FROM T_MTS_Protein_DBs
				WHERE Protein_DB_Name = @DBName AND
					  (@IncludeDeleted <> 0 OR State_ID <> 100)
			End
			Else
			If @DBTypeCurrent = 4
			Begin
				-- Look for @DBName in T_MTS_UMC_DBs
				SELECT	@ServerID = Server_ID, @DBID = UMC_DB_ID, 
						@DBNameOfficial = UMC_DB_Name
				FROM T_MTS_UMC_DBs
				WHERE UMC_DB_Name = @DBName AND
					  (@IncludeDeleted <> 0 OR State_ID <> 100)
			End
			Else
			If @DBTypeCurrent = 5
			Begin
				-- Look for @DBName in T_MTS_QCT_DBs
				SELECT	@ServerID = Server_ID, @DBID = QCT_DB_ID, 
						@DBNameOfficial = QCT_DB_Name
				FROM T_MTS_QCT_DBs
				WHERE QCT_DB_Name = @DBName AND
					  (@IncludeDeleted <> 0 OR State_ID <> 100)
			End
		End
		Else
		Begin
			-- Match using a LIKE clause
			If @DBTypeCurrent = 1
			Begin
				-- Look for @DBName in T_MTS_MT_DBs
				SELECT	TOP 1 @ServerID = Server_ID, @DBID = MT_DB_ID, 
						@DBNameOfficial = MT_DB_Name
				FROM T_MTS_MT_DBs
				WHERE MT_DB_Name LIKE @DBName AND
					  (@IncludeDeleted <> 0 OR State_ID <> 100)
				ORDER BY MT_DB_Name
			End
			Else
			If @DBTypeCurrent = 2
			Begin
				-- Look for @DBName in T_MTS_Peptide_DBs
				SELECT	TOP 1 @ServerID = Server_ID, @DBID = Peptide_DB_ID, 
						@DBNameOfficial = Peptide_DB_Name
				FROM T_MTS_Peptide_DBs
				WHERE Peptide_DB_Name LIKE @DBName AND
					  (@IncludeDeleted <> 0 OR State_ID <> 100)
				ORDER BY Peptide_DB_Name
			End
			Else
			If @DBTypeCurrent = 3
			Begin
				-- Look for @DBName in T_MTS_Protein_DBs
				SELECT	TOP 1 @ServerID = Server_ID, @DBID = Protein_DB_ID, 
						@DBNameOfficial = Protein_DB_Name
				FROM T_MTS_Protein_DBs
				WHERE Protein_DB_Name LIKE @DBName AND
					  (@IncludeDeleted <> 0 OR State_ID <> 100)
				ORDER BY Protein_DB_Name
			End
			Else
			If @DBTypeCurrent = 4
			Begin
				-- Look for @DBName in T_MTS_UMC_DBs
				SELECT	TOP 1 @ServerID = Server_ID, @DBID = UMC_DB_ID, 
						@DBNameOfficial = UMC_DB_Name
				FROM T_MTS_UMC_DBs
				WHERE UMC_DB_Name LIKE @DBName AND
					  (@IncludeDeleted <> 0 OR State_ID <> 100)
				ORDER BY UMC_DB_Name
			End
			Else
			If @DBTypeCurrent = 5
			Begin
				-- Look for @DBName in T_MTS_QCT_DBs
				SELECT	TOP 1 @ServerID = Server_ID, @DBID = QCT_DB_ID, 
						@DBNameOfficial = QCT_DB_Name
				FROM T_MTS_QCT_DBs
				WHERE QCT_DB_Name LIKE @DBName AND
					  (@IncludeDeleted <> 0 OR State_ID <> 100)
				ORDER BY QCT_DB_Name
			End
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
			Set @DBName = @DBNameOfficial
			
			-- Lookup the server name using the ID
			SELECT @serverName = Server_Name
			FROM T_MTS_Servers
			WHERE Server_ID = @ServerID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @myRowCount > 0
			Begin
				If Len(@CallingServerName) > 0 And Lower(@CallingServerName) = Lower(@serverName)
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
GRANT EXECUTE ON [dbo].[GetDBLocation] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetDBLocation] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetDBLocation] TO [MTS_DB_Lite] AS [dbo]
GO
