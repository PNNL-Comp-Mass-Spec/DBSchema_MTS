/****** Object:  StoredProcedure [dbo].[RunBlitzChecks] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure RunBlitzChecks
/****************************************************
**
**	Run various Blitz First Responder server health checks
**	Optionally save the results to physical tables
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	05/25/2017 mem - Initial version
**    
*****************************************************/
(
	@overview tinyint = 0,			-- When @overview is 1, only runs sp_BlitzFirst and sp_BlitzIndex @mode = 0; all other parameters are ignored when @overview is 1
    @runBlitz tinyint = 1,
    @runBlitzCache tinyint = 1,
    @runBlitzIndex tinyint = 1,
    @blitzIndexDatabaseList varchar(4000) = '',		-- Comma separated list of database names to run BlitzIndex on; useful when the server has over 50 databases or to limit the results
    @outputToTables tinyint = 0,
    @outputDatabaseName nvarchar(255) = 'dba',
    @outputSchemaName nvarchar(255) = 'dbo',
    @outputTableBlitz nvarchar(255) = 'T_Blitz_Results',
    @outputTableBlitzCache nvarchar(255) = 'T_BlitzCache_Results',
    @outputTableBlitzIndex nvarchar(255) = 'T_BlitzIndex_Results'
)
As
	Set XACT_ABORT, nocount on

	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------
	
	Set @overview = IsNull(@overview, 0)
	Set @runBlitz = IsNull(@runBlitz, 1)
	Set @runBlitzCache = IsNull(@runBlitzCache, 1)
	Set @runBlitzIndex = IsNull(@runBlitzIndex, 1)
	Set @blitzIndexDatabaseList = IsNull(@blitzIndexDatabaseList, '')
	Set @outputToTables = IsNull(@outputToTables, 0)
	Set @outputDatabaseName = IsNull(@outputDatabaseName, '')
	Set @outputSchemaName = IsNull(@outputSchemaName, '')
	Set @outputTableBlitz = IsNull(@outputTableBlitz, '')
	Set @outputTableBlitzCache = IsNull(@outputTableBlitzCache, '')
	Set @outputTableBlitzIndex = IsNull(@outputTableBlitzIndex, '')

	---------------------------------------------------
	-- Check for overview mode
	---------------------------------------------------
	--
	If @overview > 0
	Begin
		exec master.dbo.sp_BlitzFirst
		
		exec master.dbo.sp_BlitzIndex @mode = 0, @GetAllDatabases=1
		
		Goto Done
	End
	
	---------------------------------------------------
	-- Run sp_Blitz
	---------------------------------------------------
	--
	If @runBlitz > 0
	Begin
		If @outputToTables > 0
			exec master.dbo.sp_Blitz @OutputDatabaseName = @OutputDatabaseName, 
			                         @OutputSchemaName = @OutputSchemaName,
			                         @OutputTableName = @outputTableBlitz
		Else
			exec master.dbo.sp_Blitz
	End

	---------------------------------------------------
	-- Run sp_BlitzCache
	---------------------------------------------------
	--
	If @runBlitzCache > 0
	Begin
		If @outputToTables > 0
			exec master.dbo.sp_BlitzCache @OutputDatabaseName = @OutputDatabaseName, 
			                              @OutputSchemaName = @OutputSchemaName,
			                              @OutputTableName = @outputTableBlitzCache
		Else
			exec master.dbo.sp_BlitzCache
	End
	
	---------------------------------------------------
	-- Run sp_BlitzIndex
	---------------------------------------------------
	--
	If @runBlitzIndex > 0
	Begin -- <a>
		If @blitzIndexDatabaseList = ''
		Begin
			If @outputToTables > 0
				exec master.dbo.sp_BlitzIndex @GetAllDatabases = 1, @Mode=2,
											@OutputDatabaseName = @OutputDatabaseName, 
											@OutputSchemaName = @OutputSchemaName,
											@OutputTableName = @outputTableBlitzIndex
			Else
				exec master.dbo.sp_BlitzIndex @GetAllDatabases = 1, @Mode=2
		End
		Else
		Begin -- <b>
			CREATE TABLE #DBList ( 
				DBName varchar(255)
			)
			
			INSERT INTO #DBList (DBName)
			SELECT Value
			FROM dbo.udfParseDelimitedList(@blitzIndexDatabaseList, ',')
			
			Declare @dbName varchar(255) = ''
			Declare @continue tinyint = 1
			
			While @continue > 0
			Begin -- <c>
				SELECT TOP 1 @dbName= DBName
				FROM #DBList
				WHERE DBName > @dbName
				ORDER BY DBName
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				If @myRowCount = 0
					Set @continue = 0
				Else
				Begin -- <d>
					If @outputToTables > 0
						exec master.dbo.sp_BlitzIndex @GetAllDatabases = 0, @Mode=2,
													  @DatabaseName = @dbName,
													  @OutputDatabaseName = @OutputDatabaseName, 
													  @OutputSchemaName = @OutputSchemaName,
													  @OutputTableName = @outputTableBlitzIndex
					Else
						exec master.dbo.sp_BlitzIndex @GetAllDatabases = 0, @Mode=2,
													  @DatabaseName = @dbName,
													  @OutputDatabaseName = @OutputDatabaseName
				End -- </d>
				
			End -- </c>
		End -- </b>
	End -- </a>

Done:

	return @myError


GO
