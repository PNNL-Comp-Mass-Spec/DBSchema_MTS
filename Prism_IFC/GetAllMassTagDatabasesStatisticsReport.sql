/****** Object:  StoredProcedure [dbo].[GetAllMassTagDatabasesStatisticsReport] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetAllMassTagDatabasesStatisticsReport
/****************************************************
**
**	Desc: 
**	Returns the contents of the General_Statistics table
**  in all active MTDB's (state < 10) or in all MTDB's 
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
**		Auth: mem
**		Date: 10/23/2004
**			  12/06/2004 mem - Switched to use Pogo.MTS_Master..GetAllMassTagDatabasesStatisticsReport
**    
*****************************************************/
	@ConfigurationSettingsOnly varchar(32) = 'False',
	@ConfigurationCrosstabMode varchar(32) = 'True',
	@DBNameFilter varchar(2048) = '',
	@IncludeUnused varchar(32) = 'False',
	@message varchar(512) = '' output,
	@ServerFilter varchar(128) = ''						-- If supplied, then only examines the databases on the given Server
As
	set nocount on

	Declare @myError int
	set @myError = 0
	
	set @message = ''
	Exec @myError = Pogo.MTS_Master.dbo.GetAllMassTagDatabasesStatisticsReport @ConfigurationSettingsOnly, @ConfigurationCrosstabMode,
																		  @DBNameFilter, @IncludeUnused,
																		  @ServerFilter, @message = @message output

	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Upper(Substring(@ConfigurationSettingsOnly, 1, 1)) + ', ' + Upper(Substring(@ConfigurationCrosstabMode, 1, 1)) + ', ' + Upper(Substring(@IncludeUnused, 1, 1))
	Exec PostUsageLogEntry 'GetAllMassTagDatabasesStatisticsReport', @DBNameFilter, @UsageMessage

	
Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[GetAllMassTagDatabasesStatisticsReport] TO [DMS_SP_User]
GO
