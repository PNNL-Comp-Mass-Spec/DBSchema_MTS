/****** Object:  StoredProcedure [dbo].[GetAllPeptideDatabasesStatisticsReport] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetAllPeptideDatabasesStatisticsReport
/****************************************************
**
**	Desc: 
**	Returns the contents of T_General_Statistics_Cached
**  for all active Peptide DB's (state < 10) or in all 
**	Peptide DB's if @IncludeUnused = 'True'
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**		@ConfigurationSettingsOnly		-- 'True' to limit the report to Category 'Configuration Settings'
**		@ConfigurationCrosstabMode		-- 'True' to return a crosstab report listing Organism, Organism DB Files, Peptide Import Filters, and MTDB Export Filters
**		@DBNameFilter					-- Filter: Comma separated list of DB Names or list of DB name match criteria containing a wildcard character (%)
**										-- Example: 'PT_BSA_A54, PT_Mouse_A66'
**										--      or: 'PT_BSA%'
**										--      or: 'PT_Mouse_A66, PT_BSA%'
**		@IncludeUnused					-- 'True' to include unused databases
**		@message						 -- explanation of any error that occurred
**
**	Auth:	mem
**	Date:	10/23/2004
**			12/06/2004 mem - Ported to MTS_Master
**			07/25/2006 mem - Updated to exclude databases with state 15 and state 100 when @IncludeUnused = 'True'
**    
*****************************************************/
(
	@ConfigurationSettingsOnly varchar(32) = 'False',
	@ConfigurationCrosstabMode varchar(32) = 'True',
	@DBNameFilter varchar(2048) = '',
	@IncludeUnused varchar(32) = 'False',
	@ServerFilter varchar(128) = '',		-- If supplied, then only examines the databases on the given Server
	@message varchar(512) = '' output
)
As
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	-- Validate or clear the input/output parameters
	Set @ServerFilter = IsNull(@ServerFilter, '')
	Set @message = ''

	declare @result int
	declare @continue int
	
	declare @LastUniqueRowID int
	declare @Server varchar(64)
	declare @DBName varchar(128)
	declare @MTMain varchar(128)

	declare @Sql nvarchar(2048)
	declare @SqlWhereClause nvarchar(1024)
	declare @ParamList nvarchar(512)
	Set @ParamList = N'@Organism varchar(255) OUTPUT, @State varchar(50) OUTPUT, @LastUpdate datetime OUTPUT, @Description varchar(2048) OUTPUT'

	-- Cleanup the True/False parameters
	Exec CleanupTrueFalseParameter @ConfigurationSettingsOnly OUTPUT, 0
	Exec CleanupTrueFalseParameter @ConfigurationCrosstabMode OUTPUT, 1
	Exec CleanupTrueFalseParameter @IncludeUnused OUTPUT, 0
	
	---------------------------------------------------
	-- Create the temporary tables
	---------------------------------------------------

	--if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#PDBList]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	--	drop table #PDBList

	CREATE TABLE #PDBList (
		[DBName] [varchar] (128) NOT NULL,
		[Server_Name] [varchar] (64) NOT NULL,
		[StateID] int NOT NULL,
		[UniqueRowID] [int] IDENTITY
	)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error trying to create #PDBList temporary table'
		goto Done
	end


	CREATE TABLE #ConfigurationCrosstab (
		[Database Name] varchar(128) NOT NULL,
		[Server Name] [varchar] (64) NOT NULL,
		[Organism] varchar(128) NULL,
		[Organism DB Files] varchar(255) NULL,
		[Peptide Import Filters] varchar(255) NULL,
		[MTDB Export Filters] varchar(255) NULL,
		[State] varchar(50) NULL,
		[Last Update] datetime NULL,
		[Database Description] varchar(2048) NULL
	)
	
	
	Declare @DB_Schema_Version real
	Declare @DB_Schema_String varchar(255)

	Declare @Organism varchar(255)
	Declare @Organism_DB_Files varchar(255)
	Declare @Peptide_Import_Filter varchar(255)
	Declare @MTDB_Export_Filter varchar(255)
	Declare @State varchar(50)
	Declare @LastUpdate datetime
	Declare @Description varchar(2048)

	---------------------------------------------------
	-- Parse @DBNameFilter to create a proper
	-- SQL where clause containing a mix of 
	-- Where xx In ('A','B') and Where xx Like ('C%') statements
	---------------------------------------------------

	Declare @DBNameWhereClause varchar(8000)
	Set @DBNameWhereClause = ''

	Exec ConvertListToWhereClause @DBNameFilter, 'GSC.DBName', @entryListWhereClause = @DBNameWhereClause OUTPUT


	---------------------------------------------------
	-- Populate a temporary table with the list of 
	-- DB names to poll
	---------------------------------------------------
	--
	set @Sql = ''
	set @SqlWhereClause = ''

	set @Sql = @Sql + ' INSERT INTO #PDBList (DBName, Server_Name, StateID)'
	set @Sql = @Sql + ' SELECT GSC.DBName, GSC.Server_Name, PDBs.State_ID'
	set @Sql = @Sql + ' FROM T_MTS_Servers MTSS INNER JOIN T_MTS_Peptide_DBs PDBs ON'
	set @Sql = @Sql + '   MTSS.Server_ID = PDBs.Server_ID INNER JOIN T_General_Statistics_Cached GSC ON'
	set @Sql = @Sql + '   PDBs.Peptide_DB_Name = GSC.DBName AND MTSS.Server_Name = GSC.Server_Name'
	
	If Len(@DBNameWhereClause) > 0
	Begin
		If Len(@SqlWhereClause) > 0
			Set @SqlWhereClause = @SqlWhereClause + ' AND '
		set @SqlWhereClause = @SqlWhereClause + '(' + @DBNameWhereClause + ')'
	End
	
	If Len(@ServerFilter) > 0
	Begin
		If Len(@SqlWhereClause) > 0
			Set @SqlWhereClause = @SqlWhereClause + ' AND '
		Set @SqlWhereClause = @SqlWhereClause + 'GSC.Server_Name = ''' + @ServerFilter + ''''
	End
	
	If @IncludeUnused = 'false'
	Begin
		If Len(@SqlWhereClause) > 0
			Set @SqlWhereClause = @SqlWhereClause + ' AND '
		Set @SqlWhereClause = @SqlWhereClause + 'PDBs.State_ID < 10'
	End
	Else
	Begin
		If Len(@SqlWhereClause) > 0
			Set @SqlWhereClause = @SqlWhereClause + ' AND '
		Set @SqlWhereClause = @SqlWhereClause + 'PDBs.State_ID NOT IN (15, 100)'
	End
	
	
	If Len(@SqlWhereClause) > 0
		Set @Sql = @Sql + ' WHERE ' + @SqlWhereClause
	
	set @Sql = @Sql + ' GROUP BY GSC.DBName, GSC.Server_Name, PDBs.State_ID, PDBs.Peptide_DB_Name'
	set @Sql = @Sql + ' ORDER BY GSC.DBName, GSC.Server_Name'
	--
	exec @result = sp_executesql @Sql
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount


	If @ConfigurationCrosstabMode = 'true'
	Begin -- <A>

		-----------------------------------------------
		-- Force @ConfigurationSettingsOnly to 'false' if @ConfigurationCrosstabMode = 'true'
		-----------------------------------------------
		Set @ConfigurationSettingsOnly = 'false'

		-----------------------------------------------
		-- Process each entry in #PDBList
		-----------------------------------------------

		Set @continue = 1
		Set @LastUniqueRowID = -1
		While @continue > 0
		Begin -- <B>
		
			-- Grab next Database
			SELECT TOP 1
					@DBName = DBName, @Server = Server_Name, 
					@LastUniqueRowID = UniqueRowID
			FROM #PDBList 
			WHERE UniqueRowID > @LastUniqueRowID
			ORDER BY UniqueRowID ASC
			--		
			SELECT @myError = @@error, @myRowCount = @@rowcount
			If @myError <> 0
			Begin
				Set @message = 'Error reading next entry from table #PDBList'
				Goto done
			End
			Set @continue = @myRowCount

			If @continue > 0
			Begin -- <C>
					-- Need to generate a crosstab report
					-- However, since multiple values can be present for any given configuration setting, need to 
					--  populate a custom crosstab table

					set @DB_Schema_Version = 1
					Set @DB_Schema_String = ''

					set @Organism = ''
					set @Organism_DB_Files = ''
					set @Peptide_Import_Filter = ''
					set @MTDB_Export_Filter = ''
					set @State = ''
					set @LastUpdate = Null
					set @Description = ''

					-- Lookup the DB Schema Version
					SELECT @DB_Schema_String = Value
					FROM T_General_Statistics_Cached
					WHERE Server_Name = @Server AND DBName = @DBName AND Label = 'DB_Schema_Version'
					--
					If IsNumeric(@DB_Schema_String) = 1
						Set @DB_Schema_Version = Convert(real, @DB_Schema_String)
	
					-- If @Server is actually this server, then we do not need to prepend table names with the text
					If Lower(@Server) = Lower(@@ServerName)
						Set @MTMain = 'MT_Main.dbo.'
					Else
						Set @MTMain = @Server + '.MT_Main.dbo.'

					-- Need to poll MT_Main for most of the values
					-- @Organism and @Campaign will get overridden below for DBs with Schema Version >=2
					--
					set @Sql = ''
					set @Sql = @Sql + ' SELECT @Organism = Organism, @State = State, @LastUpdate = [Last Update], @Description = Description '
					set @Sql = @Sql + ' FROM ' + @MTMain + 'V_Peptide_Database_List_Report_Ex'
					set @Sql = @Sql + ' WHERE Name = ''' + @DBName + ''''

					EXEC @result = sp_executesql @sql, @ParamList, 
										@Organism = @Organism OUTPUT, @State = @State OUTPUT,
										@LastUpdate = @LastUpdate OUTPUT, @Description = @Description OUTPUT
					--	
					SELECT @myError = @@error, @myRowCount = @@rowcount

					
					-- Could be multiple entries present; separate with a comma
					-- Use SP ConstructGeneralStatisticsValueList to do this
					
					Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'Import_Organism_DB_File_List; Organism_DB_File_Name', @ValueList = @Organism_DB_Files OUTPUT
					Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'Peptide_Import_Filter; Filter_Set_ID', @ValueList = @Peptide_Import_Filter OUTPUT
					Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'MTDB_Export_Filter; Filter_Set_ID', @ValueList = @MTDB_Export_Filter OUTPUT
					
					-- Add a new row to #ConfigurationCrosstab
					--
					INSERT INTO #ConfigurationCrosstab (
								[Database Name], [Server Name], Organism, [Organism DB Files],
								[Peptide Import Filters], [MTDB Export Filters],
								State, [Last Update], [Database Description]
						)
					SELECT	@DBName, @Server, @Organism, @Organism_DB_Files,
							@Peptide_Import_Filter, @MTDB_Export_Filter,
							@State, @LastUpdate, @Description
					--	
					SELECT @myError = @@error, @myRowCount = @@rowcount

					
			End -- </C>

		End -- </B>
	End -- </A>
	
	---------------------------------------------------
	-- Return Statistics Report data
	---------------------------------------------------
	
	If @ConfigurationCrosstabMode = 'false'
	Begin
		-- Return the contents of T_General_Statistics_Cached, linking on
		-- #PDBList
		

		set @Sql = ''
		set @Sql = @Sql + ' SELECT GS.DBName AS [Database Name], GS.Server_Name AS [Server Name], '
		set @Sql = @Sql + '   GS.Category, GS.Label, GS.Value'
		set @Sql = @Sql + ' FROM T_General_Statistics_Cached AS GS INNER JOIN #PDBList AS ML '
		set @Sql = @Sql + '  ON GS.Server_Name = ML.Server_Name AND GS.DBName = ML.DBName'
	
		If @ConfigurationSettingsOnly = 'true'
			set @Sql = @Sql + ' WHERE (GS.Category IN (''Configuration Settings''))'

		set @Sql = @Sql + ' ORDER BY GS.DBName, GS.Server_Name, Entry_ID'
		
		exec @result = sp_executesql @Sql		
		--	
		SELECT @myError = @@error, @myRowCount = @@rowcount

	End
	Else
	Begin
		SELECT *
		FROM #ConfigurationCrosstab
		ORDER BY [Database Name], [Server Name]
		--	
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End
	

	---------------------------------------------------
	-- Exit
	---------------------------------------------------

Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[GetAllPeptideDatabasesStatisticsReport] TO [DMS_SP_User]
GO
GRANT EXECUTE ON [dbo].[GetAllPeptideDatabasesStatisticsReport] TO [MTS_DB_Lite]
GO
GRANT EXECUTE ON [dbo].[GetAllPeptideDatabasesStatisticsReport] TO [MTUser]
GO
GRANT EXECUTE ON [dbo].[GetAllPeptideDatabasesStatisticsReport] TO [pogo\MTS_DB_Dev]
GO
