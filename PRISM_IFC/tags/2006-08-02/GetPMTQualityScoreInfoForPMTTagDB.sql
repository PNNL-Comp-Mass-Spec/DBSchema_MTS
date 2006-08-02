SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetPMTQualityScoreInfoForPMTTagDB]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetPMTQualityScoreInfoForPMTTagDB]
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
**		Auth: mem
**		Date: 07/16/2005
**			  11/23/2005 mem - Added brackets around @DBName as needed to allow for DBs with dashes in the name
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
	-- Validate that DB exists on this server, determine its type,
	-- and look up its schema version
	---------------------------------------------------

	Declare @DBType tinyint				-- 1 if PMT Tag DB, 2 if Peptide DB
	Declare @DBSchemaVersion real
	
	Set @DBType = 0
	Set @DBSchemaVersion = 1
	
	Exec @myError = GetDBTypeAndSchemaVersion @DBName, @DBType OUTPUT, @DBSchemaVersion OUTPUT, @message = @message OUTPUT

	-- Make sure the type is 1 and that no errors occurred
	If @DBType = 0 Or @myError <> 0
	Begin
		If @myError = 0
			Set @myError = 20000

		If Len(@message) = 0
			Set @message = 'Database not found on this server: ' + @DBName
		Goto Done
	End
	Else
	If @DBType <> 1
	Begin
		Set @myError = 20001
		Set @message = 'Database ' + @DBName + ' is not a PMT Tag DB and is therefore not appropriate for this procedure'
		Goto Done
	End
	Else
	If @DBSchemaVersion <= 1
	Begin
		Set @myError = 20002
		Set @message = 'Database ' + @DBName + ' has a DB Schema Version less than 2 and is therefore not supported by this procedure'
		Goto Done
	End

	---------------------------------------------------
	-- build the sql query to get the data
	---------------------------------------------------
	declare @S varchar(2048)

	Set @S = ''
	Set @S = @S + ' SELECT PMT_Quality_Score_Value, Filter_Set_ID, Filter_Set_Name,'
    Set @S = @S + ' Filter_Set_Description, Experiment_Filter'
	Set @S = @S + ' FROM [' + @DBName + ']..V_Filter_Set_Overview'
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetPMTQualityScoreInfoForPMTTagDB]  TO [DMS_SP_User]
GO

