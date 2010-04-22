/****** Object:  StoredProcedure [dbo].[GetAllPeptideDatabasesStatisticsReport] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetAllPeptideDatabasesStatisticsReport
/****************************************************
**
**	Desc: 
**	Returns the contents of the General_Statistics table
**  in all active Peptide DB's (state < 10) or in all 
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
**		Auth: mem
**		Date: 10/23/2004
**			  12/06/2004 mem - Switched to use Pogo.MTS_Master..GetAllPeptideDatabasesStatisticsReport
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
	Exec @myError = Pogo.MTS_Master.dbo.GetAllPeptideDatabasesStatisticsReport @ConfigurationSettingsOnly, @ConfigurationCrosstabMode,
																		  @DBNameFilter, @IncludeUnused,
																		  @ServerFilter, @message = @message output

	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Upper(Substring(@ConfigurationSettingsOnly, 1, 1)) + ', ' + Upper(Substring(@ConfigurationCrosstabMode, 1, 1)) + ', ' + Upper(Substring(@IncludeUnused, 1, 1))
	Exec PostUsageLogEntry 'GetAllPeptideDatabasesStatisticsReport', @DBNameFilter, @UsageMessage

	
Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[GetAllPeptideDatabasesStatisticsReport] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetAllPeptideDatabasesStatisticsReport] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetAllPeptideDatabasesStatisticsReport] TO [MTS_DB_Lite] AS [dbo]
GO
