/****** Object:  StoredProcedure [dbo].[GetGeneralStatisticsForDB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE dbo.GetGeneralStatisticsForDB
/****************************************************
**
**	Desc:	Returns the contents of the General_Statistics table
**			in the given database
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	03/16/2006
**    
*****************************************************/
(
	@DBName varchar(128) = 'MT_BSA_P171',
	@ConfigurationSettingsOnly varchar(32) = 'False',
	@message varchar(512) = '' output
)
As
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''

	declare @Sql varchar(2048)
	declare @result int
	
	---------------------------------------------------
	-- Validate that DB exists on this server, determine its type,
	-- and look up its schema version
	---------------------------------------------------

	Declare @DBType tinyint				-- 1 if PMT Tag DB, 2 if Peptide DB
	Declare @DBSchemaVersion real
	
	Set @DBType = 0
	Set @DBSchemaVersion = 1
	
	Exec @myError = GetDBTypeAndSchemaVersion @DBName, @DBType OUTPUT, @DBSchemaVersion OUTPUT, @message = @message OUTPUT

	-- Make sure the type is 1 or 2 and that no errors occurred
	If @DBType = 0 Or @myError <> 0
	Begin
		If @myError = 0
			Set @myError = 20000

		If Len(@message) = 0
			Set @message = 'Database not found on this server: ' + @DBName
		Goto Done
	End
	Else
	If @DBType <> 1 AND @DBType <> 2
	Begin
		Set @myError = 20001
		Set @message = 'Database ' + @DBName + ' is not a Peptide or PMT Tag DB and is therefore not appropriate for this procedure'
		Goto Done
	End

	---------------------------------------------------
	-- Cleanup the input parameters
	---------------------------------------------------

	-- Cleanup the True/False parameters
	Exec CleanupTrueFalseParameter @ConfigurationSettingsOnly OUTPUT, 0


	---------------------------------------------------
	-- Build the sql query to get the contents of V_General_Statistics_Report
	---------------------------------------------------
	
	set @Sql = ''
	set @Sql = @Sql + ' SELECT Category, Label, Value'
	set @Sql = @Sql + ' FROM [' + @DBName + ']..V_General_Statistics_Report'

	If @ConfigurationSettingsOnly = 'true'
		set @Sql = @Sql + ' WHERE (Category IN (''Configuration Settings'', ''Import Parameters For Peptides'', ''Organism DB files allowed for importing LCQ analyses'', ''Parameter files allowed for importing LCQ analyses'', ''External References''))'

	set @Sql = @Sql + ' ORDER BY Entry_ID'


	---------------------------------------------------
	-- Run the query
	---------------------------------------------------
	Exec (@Sql)
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount


	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Upper(Substring(@ConfigurationSettingsOnly, 1, 1))
	Exec PostUsageLogEntry 'GetGeneralStatisticsForDB', @DBName, @UsageMessage

	
Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[GetGeneralStatisticsForDB] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetGeneralStatisticsForDB] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetGeneralStatisticsForDB] TO [MTS_DB_Lite] AS [dbo]
GO
