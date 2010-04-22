/****** Object:  StoredProcedure [dbo].[CheckMTSDBs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.CheckMTSDBs
/****************************************************
**
**	Desc:	Runs DBCC CHECKDB and/or DBCC SHRINKDATABASE 
**			against the sepecified MTS DBs
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	08/26/2006
**    
*****************************************************/
(
	@DBNameMatchList varchar(2048) = 'MT[_]%',		-- Comma-separated list of databases on this server to include; can include wildcard symbols since used with a LIKE clause.  Leave blank to ignore this parameter
	@IncludeMTSInterfaceAndControlDBs tinyint = 0,	-- Set to 1 to include MTS_Master, MT_Main, MT_HistoricLog, and Prism_IFC, & Prism_RPT
	@IncludeSystemDBs tinyint = 0,
	@CheckDB tinyint = 1,							-- Set to 1 to call DBCC CHECKDB against each DB
	@ShrinkDB tinyint = 1,							-- Set to 1 to call DBCC SHRINKDATABASE against each DB
	@CheckPhysicalOnly tinyint = 0,					-- Set to 1 to use the PHYSICAL_ONLY switch with DBCC, which performs a quick, less thorough check of each DB
	@ShrinkTargetPercent tinyint = 10,				-- Target percentage for shrinking each database
	@InfoOnly tinyint = 0,							-- Set to 1 to display the SQL that would be run
	@message varchar(255) = '' OUTPUT
)
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	-- Validate the inputs
	Set @DBNameMatchList = LTrim(RTrim(IsNull(@DBNameMatchList, '')))

	Set @IncludeMTSInterfaceAndControlDBs = IsNull(@IncludeMTSInterfaceAndControlDBs, 0)
	Set @IncludeSystemDBs = IsNull(@IncludeSystemDBs, 0)
	
	Set @CheckPhysicalOnly = IsNull(@CheckPhysicalOnly, 0)
	Set @ShrinkTargetPercent = IsNull(@ShrinkTargetPercent, 10)
	If @ShrinkTargetPercent < 1
		Set @ShrinkTargetPercent = 1
	
	If @ShrinkTargetPercent > 100
		Set @ShrinkTargetPercent = 100

	Set @InfoOnly = IsNull(@InfoOnly, 0)
	Set @message = ''

	---------------------------------------
	-- Make sure either @CheckDB or @ShrinkDB is non-zero
	-- If not, then there is nothing to do
	---------------------------------------
	
	If @CheckDB = 0 And @ShrinkDB = 0
	Begin
		Set @Message = 'Nothing to do since both @CheckDB and @ShrinkDB are 0'

		If @InfoOnly <> 0
			SELECT @Message As TheMessage
			
		Return 0
	End
	
	Declare @DBName nvarchar(255)
	Declare @DBsProcessed varchar(255)
	Set @DBsProcessed = ''
	
	Declare @Sql varchar(4000)
	Declare @SqlCheck nvarchar(4000)
	Declare @SqlShrink nvarchar(4000)
	
	Declare @continue tinyint
	Declare @DBProcessCount int
	Set @DBProcessCount = 0
	
	Declare @CharLoc int
	
	---------------------------------------
	-- Create a temporary table to hold the databases to process
	---------------------------------------
	If Exists (SELECT [Name] FROM sysobjects WHERE [Name] = '#Tmp_DB_List')
		DROP TABLE #Tmp_DB_List

	CREATE TABLE #Tmp_DB_List (
		DatabaseName varchar(255) NOT NULL
	)

	CREATE CLUSTERED INDEX #IX_Tmp_DB_Backup_List ON #Tmp_DB_List (DatabaseName)

	---------------------------------------
	-- Optionally include the system databases
	---------------------------------------
	If @IncludeSystemDBs <> 0
	Begin
		INSERT INTO #Tmp_DB_List (DatabaseName) VALUES ('Master')
		INSERT INTO #Tmp_DB_List (DatabaseName) VALUES ('Model')
		INSERT INTO #Tmp_DB_List (DatabaseName) VALUES ('MSDB')
	End

	---------------------------------------
	-- Optionally include the MTS databases
	-- If any of these do not exist on this server, then they will be deleted below
	---------------------------------------
	If @IncludeMTSInterfaceAndControlDBs <> 0
	Begin
		INSERT INTO #Tmp_DB_List (DatabaseName) VALUES ('MTS_Master')
		INSERT INTO #Tmp_DB_List (DatabaseName) VALUES ('MT_Main')
		INSERT INTO #Tmp_DB_List (DatabaseName) VALUES ('MT_HistoricLog')
		INSERT INTO #Tmp_DB_List (DatabaseName) VALUES ('Prism_IFC')
		INSERT INTO #Tmp_DB_List (DatabaseName) VALUES ('Prism_RPT')
	End


	---------------------------------------
	-- Look for databases on this server that match @DBNameMatchList
	---------------------------------------
	If Len(@DBNameMatchList) > 0
	Begin
		-- Make sure @DBNameMatchList ends in a comma
		If Right(@DBNameMatchList,1) <> ','
			Set @DBNameMatchList = @DBNameMatchList + ','

		-- Split @DBNameMatchList on commas and loop

		Set @continue = 1
		While @continue <> 0
		Begin
			Set @CharLoc = CharIndex(',', @DBNameMatchList)
			
			If @CharLoc <= 0
				Set @continue = 0
			Else
			Begin
				Set @DBName = LTrim(RTrim(SubString(@DBNameMatchList, 1, @CharLoc-1)))
				Set @DBNameMatchList = LTrim(SubString(@DBNameMatchList, @CharLoc+1, Len(@DBNameMatchList) - @CharLoc))

				Set @Sql = ''
				Set @Sql = @Sql + ' INSERT INTO #Tmp_DB_List (DatabaseName)'
				Set @Sql = @Sql + ' SELECT [Name]'
				Set @Sql = @Sql + ' FROM master.dbo.sysdatabases SD LEFT OUTER JOIN '
				Set @Sql = @Sql +      ' #Tmp_DB_List DBList ON SD.Name = DBList.DatabaseName'
				Set @Sql = @Sql + ' WHERE [Name] LIKE ''' + @DBName + ''' And DBList.DatabaseName IS Null'
				
				Exec (@Sql)
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
			End
		End
	End


	---------------------------------------
	-- Delete databases defined in #Tmp_DB_List that are not defined in sysdatabases
	---------------------------------------
	DELETE #Tmp_DB_List
	FROM #Tmp_DB_List DBList LEFT OUTER JOIN
		 master.dbo.sysdatabases SD ON SD.Name = DBList.DatabaseName
	WHERE SD.Name IS Null
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	
	If @myRowCount > 0
		Set @message = 'Deleted ' + Convert(varchar(9), @myRowCount) + ' non-existent databases'
	

	---------------------------------------
	-- Count the number of databases in #Tmp_DB_List
	---------------------------------------
	Set @myRowCount = 0
	SELECT @myRowCount = COUNT(*)
	FROM #Tmp_DB_List
	
	If @myRowCount = 0
	Begin
		Set @Message = 'Warning: no databases were found matching the given specifications'
		Goto Done
	End


	---------------------------------------
	-- Loop through the databases in #Tmp_DB_List
	-- and run CheckDB
	-- Then process the remaining DBs
	---------------------------------------
	Set @continue = 1
	While @continue <> 0
	Begin -- <a>
		SELECT TOP 1 @DBName = DatabaseName
		FROM #Tmp_DB_List
		ORDER BY DatabaseName
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		If @myRowCount <> 1
		Begin
			Set @continue = 0
		End
		Else
		Begin -- <b>
			DELETE FROM #Tmp_DB_List
			WHERE @DBName = DatabaseName

			---------------------------------------
			-- Construct the DBCC commands for this DB
			--
			-- Note: Do not add square brackets around @DBName (as is typically done when DBs
			--  contain characters besides letters, numbers, or underscores);
			--  DBCC neither requires nor allows square brackets around DB names
			---------------------------------------

			If @CheckDB <> 0
			Begin
				Set @SqlCheck = N'DBCC CHECKDB (''' + @DBName + ''') WITH NO_INFOMSGS'
				If @CheckPhysicalOnly <> 0
					Set @SqlCheck = @SqlCheck + ', PHYSICAL_ONLY'
			End
			Else
				Set @SqlCheck = ''

			
			If @ShrinkDB <> 0
				Set @SqlShrink = N'DBCC SHRINKDATABASE (''' + @DBName + ''', ' + Convert(nvarchar(9), @ShrinkTargetPercent) + ', TRUNCATEONLY)'
			Else
				Set @SqlShrink = ''
			

			If @InfoOnly = 0
			Begin -- <c1>
				If @CheckDB <> 0
				Begin
					Exec @myError = sp_executesql @SqlCheck
					
					If @myError <> 0
					Begin
						---------------------------------------
						-- Error occurred; post a log entry
						---------------------------------------
						Set @message = 'Error calling DBCC CHECKDB for DB ' + @DBName + '; SQL error code: ' + Convert(varchar(19), @myError)
						Execute PostLogEntry 'Error', @message, 'CheckMTSDBs'
					End
				End

				If @ShrinkDB <> 0
				Begin
					Exec @myError = sp_executesql @SqlShrink
					
					If @myError <> 0
					Begin
						---------------------------------------
						-- Error occurred; post a log entry
						---------------------------------------
						Set @message = 'Error calling DBCC SHRINKDATABASE for DB ' + @DBName + '; SQL error code: ' + Convert(varchar(19), @myError)
						Execute PostLogEntry 'Error', @message, 'CheckMTSDBs'
					End
				End
			End -- </c1>
			Else
			Begin -- <c2>
				---------------------------------------
				-- Preview the DBCC Sql
				---------------------------------------
				If @CheckDB <> 0
					Print @SqlCheck
					
				If @ShrinkDB <> 0
					Print @SqlShrink
			End -- </c2>

			---------------------------------------
			-- Append @DBName to @DBsProcessed, limiting to 175 characters, 
			--  afterwhich a period is added for each additional DB
			---------------------------------------
			If Len(@DBsProcessed) = 0
				Set @DBsProcessed = @DBName
			Else
			Begin
				If Len(@DBsProcessed) <= 175
					Set @DBsProcessed = @DBsProcessed + ', ' + @DBName
				Else
					Set @DBsProcessed = @DBsProcessed + '.'
			End
			
			Set @DBProcessCount = @DBProcessCount + 1
		End -- </b>
	End -- </a>


	If @DBProcessCount = 0
		Set @Message = 'Warning: no databases were found matching the given specifications'
	Else
	Begin
		Set @Message = 'DB Maintenance Complete (CheckDB=' + Convert(varchar(3), @CheckDB) + '; ShrinkDB=' + Convert(varchar(3), @ShrinkDB) + ')'
		Set @Message = @Message + '; ProcessCount=' + Convert(varchar(9), @DBProcessCount) + ': ' + @DBsProcessed
	End
	
	---------------------------------------
	-- Post a Log entry if @DBProcessCount > 0 and @InfoOnly = 0
	---------------------------------------
	If @InfoOnly = 0
	Begin
		If @DBProcessCount > 0
			Execute PostLogEntry 'Normal', @message, 'CheckMTSDBs'
	End
	Else
		SELECT @Message As TheMessage


Done:
	DROP TABLE #Tmp_DB_List

	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[CheckMTSDBs] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CheckMTSDBs] TO [MTS_DB_Lite] AS [dbo]
GO
