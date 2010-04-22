/****** Object:  StoredProcedure [dbo].[GetPMTQualityScoreInfoForPMTTagDB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetPMTQualityScoreInfoForPMTTagDB
/****************************************************
**
**	Desc: 
**	Returns list of PMT Quality Score values defined for the given PMT Tag DB
**  This is useful when designing custom queries that filter the entries in
**  T_Peptides to only contain those with a match to a given filter ID (using T_Mass_Tags)
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @DBName				-- PMT Tag database name
**	  @message				-- Status/error message output
**
**	Auth:	mem
**	Date:	07/16/2005
**			11/23/2005 mem - Added brackets around @DBName as needed to allow for DBs with dashes in the name
**			09/21/2009 mem - Now using GetDBLocation to determine the DB location (including server name if not on this server)
**
*****************************************************/
	@DBName varchar(128) = '',
	@message varchar(512) = '' output
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''

	---------------------------------------------------
	-- Lookup the path to the specified DB
	---------------------------------------------------

	Declare @DBType tinyint				-- 1 if PMT Tag DB, 2 if Peptide DB, 3 if Protein DB (deprecated)
	Declare @serverName varchar(64)
	Declare @DBPath varchar(256)		-- Path to the DB, including the server name (if not on this server), e.g. ServerName.DBName
	Declare @DBID int

	Exec GetDBLocation @DBName, @DBType OUTPUT, @serverName output, @DBPath output, @DBID output, @message output, @IncludeDeleted=0

	If IsNull(@DBPath, '') = ''
	Begin
		If @myError = 0
			Set @myError = 20000

		If Len(@message) = 0
			Set @message = 'Database not found in MTS: ' + @DBName
		Goto Done
	End

	If @DBType <> 1
	Begin
		Set @myError = 20001
		Set @message = 'Database ' + @DBName + ' is not a PMT Tag DB and is therefore not appropriate for this procedure'
		Goto Done
	End

	---------------------------------------------------
	-- build the sql query to get the data
	---------------------------------------------------
	declare @S varchar(2048)

	Set @S = ''
	Set @S = @S + ' SELECT PMT_Quality_Score_Value, Filter_Set_ID, Filter_Set_Name,'
    Set @S = @S + ' Filter_Set_Description, Experiment_Filter'
	Set @S = @S + ' FROM ' + @DBPath + '.dbo.V_Filter_Set_Overview'
	Set @S = @S + ' ORDER BY PMT_Quality_Score_Value'	
	
	-- Obtain the data
	Exec (@S)
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows'
	
	Exec PostUsageLogEntry 'GetPMTQualityScoreInfoForPMTTagDB', @DBName, @UsageMessage
	
Done:
	return @myError


GO
GRANT EXECUTE ON [dbo].[GetPMTQualityScoreInfoForPMTTagDB] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetPMTQualityScoreInfoForPMTTagDB] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetPMTQualityScoreInfoForPMTTagDB] TO [MTS_DB_Lite] AS [dbo]
GO
