/****** Object:  StoredProcedure [dbo].[GetAllMassTagDatabasesStatisticsReport] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetAllMassTagDatabasesStatisticsReport
/****************************************************
**
**	Desc: 
**	Returns the contents of T_General_Statistics_Cached
**  for all active MTDB's (state < 10) or in all MTDB's 
**	if @IncludeUnused = 'True'
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**		@ConfigurationSettingsOnly		-- 'True' to limit the report to Category 'Configuration Settings'
**		@ConfigurationCrosstabMode		-- 'True' to return a crosstab report listing Campaign, Peptide_DB_Name, Protein_DB_Name, Organism_DB_File_Name, etc.
**		@DBNameFilter					-- Filter: Comma separated list of DB Names or list of DB name match criteria containing a wildcard character (%)
**										-- Example: 'MT_BSA_P124, MT_BSA_P171'
**										--      or: 'MT_BSA%'
**										--      or: 'MT_Shewanella_P96, MT_BSA%'
**		@IncludeUnused					-- 'True' to include unused databases
**		@message						 -- explanation of any error that occurred
**
**	Auth:	mem
**	Date:	10/23/2004
**			12/06/2004 mem - Ported to MTS_Master
**			07/25/2006 mem - Updated to exclude databases with state 15 and state 100 when @IncludeUnused = 'True'
**			12/08/2006 mem - Added parameter @AddWildcardChars
**						   - Now returning [Protein Collections], [Seq Directions], and [MSMS Result Types] in the output
**			07/21/2009 mem - Added Try/Catch error handling, including allowing for any of the servers to not be available
**
*****************************************************/
(
	@ConfigurationSettingsOnly varchar(32) = 'False',		-- Ths will be set to 'False' if @ConfigurationCrosstabMode = 'True'
	@ConfigurationCrosstabMode varchar(32) = 'True',
	@DBNameFilter varchar(2048) = '',
	@IncludeUnused varchar(32) = 'False',
	@ServerFilter varchar(128) = '',		-- If supplied, then only examines the databases on the given Server
	@message varchar(512) = '' output,
	@AddWildcardChars tinyint = 1			-- If 1, then adds percent signs to the beginning and end of @DBNameFilter if it does not contain a percent sign
)
As
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @result int
	declare @continue int
	
	declare @LastUniqueRowID int
	declare @Server varchar(64)
	declare @DBName varchar(128)
	declare @MTMain varchar(128)

	declare @Sql nvarchar(2048)
	declare @SqlWhereClause nvarchar(1024)
	declare @ParamList nvarchar(512)
	Set @ParamList = N'@Organism varchar(255) OUTPUT, @Campaign varchar(255) OUTPUT, @State varchar(50) OUTPUT, @LastUpdate datetime OUTPUT, @Description varchar(2048) OUTPUT'

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		
		-----------------------------------------------------------
		-- Validate the inputs
		-----------------------------------------------------------
		-- Cleanup the True/False parameters
		Exec CleanupTrueFalseParameter @ConfigurationSettingsOnly OUTPUT, 0
		Exec CleanupTrueFalseParameter @ConfigurationCrosstabMode OUTPUT, 1
		Exec CleanupTrueFalseParameter @IncludeUnused OUTPUT, 0
		
		Set @DBNameFilter = IsNull(@DBNameFilter, '')
		Set @ServerFilter = IsNull(@ServerFilter, '')
		Set @message = ''

		If Len(@DBNameFilter) > 0
		Begin
			If @AddWildcardChars <> 0
				If CharIndex('%', @DBNameFilter) = 0
					Set @DBNameFilter = '%' + @DBNameFilter + '%'
		End
			
		
		---------------------------------------------------
		-- Create the temporary tables
		---------------------------------------------------

		--if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#MTDBList]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		--	drop table #MTDBList

		CREATE TABLE #MTDBList (
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
			set @message = 'Error trying to create #MTDBList temporary table'
			goto Done
		end


		CREATE TABLE #ConfigurationCrosstab (
			[Database Name] varchar(128) NOT Null,
			[Database Description] varchar(2048) NULL,
			[Server Name] [varchar] (64) NOT NULL,
			[Database Campaign] varchar(255) NULL,
			[Organism] varchar(128) NULL,
			[Peptide DB] varchar(255) NULL,
			[Protein DB] varchar(255) NULL,
			[Organism DB Files] varchar(255) NULL,
			[Protein Collections] varchar(255) NULL,
			[Seq Directions] varchar(255) NULL,
			[Parameter Files] varchar(255) NULL,
			[Settings Files] varchar(255) NULL,
			[MSMS Result Types] varchar(255) NULL,
			[Separation Types] varchar(255) NULL,
			[Experiments] varchar(255) NULL,
			[State] varchar(50) NULL,
			[Last Update] datetime NULL
		)
		
		
		Declare @DB_Schema_Version real
		Declare @DB_Schema_String varchar(255)

		Declare @Campaign varchar(255)
		Declare @Organism varchar(255)
		Declare @Peptide_DB varchar(255)
		Declare @Protein_DB varchar(255)
		Declare @Organism_DB_File varchar(255)
		Declare @Protein_Collection_Filter varchar(255)
		Declare @Seq_Direction_Filter varchar(255)
		Declare @MSMS_Result_Type varchar(255)
		Declare @Parameter_File varchar(255)
		Declare @Settings_File_Name varchar(255)
		Declare @Separation_Type varchar(255) 
		Declare @Experiment varchar(255)
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

		set @Sql = @Sql + ' INSERT INTO #MTDBList (DBName, Server_Name, StateID)'
		set @Sql = @Sql + ' SELECT GSC.DBName, GSC.Server_Name, MTDBs.State_ID'
		set @Sql = @Sql + ' FROM T_MTS_Servers MTSS INNER JOIN T_MTS_MT_DBs MTDBs ON'
		set @Sql = @Sql + '   MTSS.Server_ID = MTDBs.Server_ID INNER JOIN T_General_Statistics_Cached GSC ON'
		set @Sql = @Sql + '   MTDBs.MT_DB_Name = GSC.DBName AND MTSS.Server_Name = GSC.Server_Name'
		
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
			Set @SqlWhereClause = @SqlWhereClause + 'MTDBs.State_ID < 10'
		End
		Else
		Begin
			If Len(@SqlWhereClause) > 0
				Set @SqlWhereClause = @SqlWhereClause + ' AND '
			Set @SqlWhereClause = @SqlWhereClause + 'MTDBs.State_ID NOT IN (15, 100)'
		End
		
		If Len(@SqlWhereClause) > 0
			Set @Sql = @Sql + ' WHERE ' + @SqlWhereClause
		
		set @Sql = @Sql + ' GROUP BY GSC.DBName, GSC.Server_Name, MTDBs.State_ID, MTDBs.MT_DB_Name'
		set @Sql = @Sql + ' ORDER BY GSC.DBName, GSC.Server_Name'
		--
		exec @result = sp_executesql @Sql
		--	
		SELECT @myError = @@error, @myRowCount = @@rowcount


		If @ConfigurationCrosstabMode = 'true'
		Begin -- <a>

			-----------------------------------------------
			-- Force @ConfigurationSettingsOnly to 'false' if @ConfigurationCrosstabMode = 'true'
			-----------------------------------------------
			Set @ConfigurationSettingsOnly = 'false'

			-----------------------------------------------
			-- Process each entry in #MTDBList
			-----------------------------------------------

			Set @continue = 1
			Set @LastUniqueRowID = -1
			While @continue > 0
			Begin -- <b>
			
				-- Grab next Database
				SELECT TOP 1
						@DBName = DBName, @Server = Server_Name,
						@LastUniqueRowID = UniqueRowID
				FROM #MTDBList 
				WHERE UniqueRowID > @LastUniqueRowID
				ORDER BY UniqueRowID ASC
				--		
				SELECT @myError = @@error, @myRowCount = @@rowcount
				If @myError <> 0
				Begin
					Set @message = 'Error reading next entry from table #MTDBList'
					Goto done
				End
				Set @continue = @myRowCount

				If @continue > 0
				Begin -- <c>
						-- Need to generate a crosstab report
						-- However, since multiple values can be present for any given configuration setting, need to 
						--  populate a custom crosstab table

						set @DB_Schema_Version = 1
						Set @DB_Schema_String = ''
						
						set @Campaign = ''
						set @Organism = ''
						set @Peptide_DB = ''
						set @Protein_DB = ''
						set @Organism_DB_File = ''
						set @Protein_Collection_Filter = ''
						set @Seq_Direction_Filter = ''
						set @MSMS_Result_Type = ''
						set @Parameter_File = ''
						set @Settings_File_Name = ''
						set @Separation_Type = '' 
						set @Experiment = ''
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
		
						Begin Try
							Set @CurrentLocation = 'Query MT_Main on server ' + @Server
							
							-- If @Server is actually this server, then we do not need to prepend table names with the text
							If Lower(@Server) = Lower(@@ServerName)
								Set @MTMain = 'MT_Main.dbo.'
							Else
								Set @MTMain = @Server + '.MT_Main.dbo.'
							
							-- Need to poll MT_Main for a few values
							-- @Organism and @Campaign will get overridden below for DBs with Schema Version >=2
							--
							set @Sql = ''
							set @Sql = @Sql + ' SELECT @Organism = Organism, @Campaign = Campaign, @State = State, @LastUpdate = [Last Update], @Description = Description '
							set @Sql = @Sql + ' FROM ' + @MTMain + 'V_MT_Database_List_Report_Ex'
							set @Sql = @Sql + ' WHERE Name = ''' + @DBName + ''''

							EXEC @result = sp_executesql @sql, @ParamList, 
												@Organism = @Organism OUTPUT, @Campaign = @Campaign OUTPUT, 
												@State = @State OUTPUT, @LastUpdate = @LastUpdate OUTPUT, 
												@Description = @Description OUTPUT
							--	
							SELECT @myError = @@error, @myRowCount = @@rowcount
							
						End Try
						Begin Catch
							-- Error caught; log the error but continue processing
							Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'GetAllMassTagDatabasesStatisticsReport')
							exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
													@ErrorNum = @myError output, @message = @message output
						
						End Catch
						
						Set @CurrentLocation = 'Call ConstructGeneralStatisticsValueList for DB  ' + @DBName + ' on server ' + @Server
						
						If @DB_Schema_Version < 2
						Begin
							Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'Peptide Database', @ValueList = @Peptide_DB OUTPUT
							Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'ORF Database', @ValueList = @Protein_DB OUTPUT
							Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'Organism DB files allowed for importing LCQ analyses', @ValueList = @Organism_DB_File OUTPUT, @UseCategoryField = 1
							Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'Parameter files allowed for importing LCQ analyses', @ValueList = @Parameter_File OUTPUT, @UseCategoryField = 1
						End
						Else
						Begin
							-- Could be multiple entries present; separate with a comma
							-- Use SP ConstructGeneralStatisticsValueList to do this
							
							Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'Organism', @ValueList = @Organism OUTPUT
							Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'Campaign', @ValueList = @Campaign OUTPUT
							Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'Peptide_DB_Name', @ValueList = @Peptide_DB OUTPUT
							Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'Protein_DB_Name', @ValueList = @Protein_DB OUTPUT
							Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'Organism_DB_File_Name', @ValueList = @Organism_DB_File OUTPUT
							
							Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'Protein_Collection_Filter', @ValueList = @Protein_Collection_Filter OUTPUT
							Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'Seq_Direction_Filter', @ValueList = @Seq_Direction_Filter OUTPUT
							Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'MSMS_Result_Type', @ValueList = @MSMS_Result_Type OUTPUT

							Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'Parameter_File_Name', @ValueList = @Parameter_File OUTPUT
							Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'Settings_File_Name', @ValueList = @Settings_File_Name OUTPUT
							Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'Separation_Type', @ValueList = @Separation_Type OUTPUT
							Exec ConstructGeneralStatisticsValueList @Server, @DBName, 'Experiment', @ValueList = @Experiment OUTPUT
						
						End
		
						
						-- Add a new row to #ConfigurationCrosstab
						--
						INSERT INTO #ConfigurationCrosstab (
									[Database Name], [Server Name], [Database Campaign], Organism, 
									[Peptide DB], [Protein DB], [Organism DB Files], 
									[Protein Collections], [Seq Directions],
									[Parameter Files], [Settings Files], 
									[MSMS Result Types], [Separation Types], 
									Experiments, State, [Last Update], [Database Description]
							)
						SELECT	@DBName, @Server, @Campaign, @Organism, 
								@Peptide_DB, @Protein_DB, @Organism_DB_File, 
								@Protein_Collection_Filter, @Seq_Direction_Filter,
								@Parameter_File, @Settings_File_Name, 
								@MSMS_Result_Type, @Separation_Type, @Experiment, 
								@State, @LastUpdate, @Description
						--	
						SELECT @myError = @@error, @myRowCount = @@rowcount

						
				End -- </c>

			End -- </b>
		End -- </a>
		
		---------------------------------------------------
		-- Return Statistics Report data
		---------------------------------------------------
		
		If @ConfigurationCrosstabMode = 'false'
		Begin
			-- Return the contents of T_General_Statistics_Cached, linking on
			-- #MTDBList

			set @Sql = ''
			set @Sql = @Sql + ' SELECT GS.DBName AS [Database Name], GS.Server_Name AS [Server Name],'
			set @Sql = @Sql + '   GS.Category, GS.Label, GS.Value'
			set @Sql = @Sql + ' FROM T_General_Statistics_Cached AS GS INNER JOIN #MTDBList AS ML '
			set @Sql = @Sql + '  ON GS.Server_Name = ML.Server_Name AND GS.DBName = ML.DBName'
		
			If @ConfigurationSettingsOnly = 'true'
				set @Sql = @Sql + ' WHERE (GS.Category IN (''Configuration Settings'', ''Import Parameters For Peptides'', ''Organism DB files allowed for importing LCQ analyses'', ''Parameter files allowed for importing LCQ analyses'', ''External References''))'

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
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'GetAllMassTagDatabasesStatisticsReport')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch

Done:
	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--
	return @myError

GO
GRANT EXECUTE ON [dbo].[GetAllMassTagDatabasesStatisticsReport] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetAllMassTagDatabasesStatisticsReport] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetAllMassTagDatabasesStatisticsReport] TO [MTS_DB_Lite] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[GetAllMassTagDatabasesStatisticsReport] TO [pogo\MTS_DB_Dev] AS [dbo]
GO
