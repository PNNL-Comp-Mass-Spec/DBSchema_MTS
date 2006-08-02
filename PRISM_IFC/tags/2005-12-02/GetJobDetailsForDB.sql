SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetJobDetailsForDB]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetJobDetailsForDB]
GO

CREATE PROCEDURE dbo.GetJobDetailsForDB
/****************************************************
**
**	Desc: 
**	Returns list of analysis jobs in the given datasbase (Peptide or MTDB).  
**  For MTDBs, returns the analysis jobs for the given match method
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @DBName				-- Peptide or PMT Tag database name
**	  @criteriaSql			-- Sql "Where clause compatible" text for filtering ResultSet
**							--   Example: Protein_Name Like 'DR2%' And (MSMS_High_Normalized_Score >= 5 Or MSMS_Observation_Count >= 10)
**							-- Although this parameter can contain Protein_Name criteria, it is better to filter for Proteins using the @Proteins parameter
**	  @returnRowCount		-- Set to True to return a row count; False to return the mass tags
**	  @message				-- Status/error message output
**	  @pepIdentMethod		-- Can be DBSearch(MS/MS-LCQ) or UMCPeakMatch(MS-FTICR);
**	  @experiments			-- Filter: Comma separated list of experiments or list of experiment match criteria containing a wildcard character(%)
**							--   Names do not need single quotes around them; see @Proteins parameter for examples

**
**		Auth: mem
**		Date: 08/16/2005
**			  11/23/2005 mem - Added brackets around @DBName as needed to allow for DBs with dashes in the name
**
*****************************************************/
	@DBName varchar(128) = '',
	@criteriaSql varchar(6000) = '',
	@returnRowCount varchar(32) = 'False',
	@message varchar(512) = '' output,
	@pepIdentMethod varchar(32) = '',
	@experiments varchar(7000) = '',
	@datasets varchar(7000) = ''
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

	-- Make sure the type is 1 or 2
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
		Set @message = 'Database ' + @DBName + ' is not a Peptide DB or a PMT Tag DB and is therefore not appropriate for this procedure'
		Goto Done
	End

	
	---------------------------------------------------
	-- resolve match method name to internal code
	-- Note that if @pepIdentMethod does not match any entries
	-- in T_Match_Methods, then we will assume 'PMT', i.e. DBSearch(MS/MS-LCQ)
	---------------------------------------------------
	declare @internalMatchCode varchar(32)
	set @internalMatchCode = 'PMT'
	--
	If Len(@pepIdentMethod) > 0
	Begin
		SELECT @internalMatchCode = Internal_Code
		FROM T_Match_Methods
		WHERE ([Name] = @pepIdentMethod)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Could not resolve match methods'
			goto Done
		end
		if @myRowCount = 0
			set @internalMatchCode = 'PMT'
	End

	---------------------------------------------------
	-- build the sql query to get the data
	---------------------------------------------------
	declare @sqlSelect varchar(2048)
	declare @sqlFrom varchar(2048)
	declare @sqlWhere varchar(8000)
	declare @sqlOrderBy varchar(2048)

	-- Construct the base Select clause, using Distinct to return a unique list of instrument names
	Set @sqlSelect = 'SELECT *'

	-- Construct the From and Where clauses
	Set @sqlFrom = 'FROM '
	Set @sqlWhere = ''

	If @DBType = 2
	Begin
		-- Peptide DB
		Set @sqlFrom = @sqlFrom + '[' + @DBName + ']..V_MSMS_Analysis_Jobs AS JobTable'
	End
	Else
	Begin
		-- PMT Tag DB
		if @internalMatchCode = 'PMT'
			Set @sqlFrom = @sqlFrom + '[' + @DBName + ']..V_MSMS_Analysis_Jobs AS JobTable'
		else
		Begin
			-- Assume @internalMatchCode = 'UMC'
			Set @sqlFrom = @sqlFrom + '[' + @DBName + ']..V_MS_Analysis_Jobs AS JobTable'
		End
	End

	---------------------------------------------------
	-- Parse @experiments and @datasets to create a proper
	-- SQL where clause containing a mix of 
	-- Where xx In ('A','B') and Where xx Like ('C%') statements
	---------------------------------------------------

	Declare @experimentWhereClause varchar(8000),
			@datasetWhereClause varchar(8000)
	Set @experimentWhereClause = ''
	Set @datasetWhereClause = ''

	Exec ConvertListToWhereClause @experiments, 'Experiment', @entryListWhereClause = @experimentWhereClause OUTPUT
	Exec ConvertListToWhereClause @datasets, 'Dataset', @entryListWhereClause = @datasetWhereClause OUTPUT

	-- Add the Ad Hoc Where criteria, if applicable
	Set @criteriaSql = IsNull(@criteriaSql, '')
	If @criteriaSql = 'na'
		Set @criteriaSql = ''

	If Len(@criteriaSql) > 0
		Set @sqlWhere = 'WHERE (' + @criteriaSql + ')'
	Else
		Set @sqlWhere = 'WHERE 1=1'			-- This will always be true; it is used to simplify the logic statements below


	-- We could append @experimentWhereClause and @datasetWhereClause to @sqlWhere, but the string length
	-- could become too long; thus, we'll add it in when we combine the Sql to Execute
	-- However, we need to prepend them with AND

	If Len(@experimentWhereClause) > 0
		Set @experimentWhereClause = ' AND (' + @experimentWhereClause + ')'

	If Len(@datasetWhereClause) > 0
		Set @datasetWhereClause = ' AND (' + @datasetWhereClause + ')'
	
	
	-- Define the sort order if not returning the row count
	Set @sqlOrderBy = ' ORDER BY Job'

	
	-- Obtain the data
	If @returnRowCount = 'true'
	begin
		-- In order to return the row count, we wrap the sql text with Count (*) 
		-- and exclude the @sqlOrderBy text from the sql statement
		Exec ('SELECT Count (*) As ResultSet_Row_Count FROM (' + @sqlSelect + ' ' + @sqlFrom + ' ' + @sqlWhere + @experimentWhereClause + @datasetWhereClause + ') As LookupQ')
	end
	Else
	begin
		--Print @sqlSelect + ' ' + @sqlFrom + ' ' + @sqlWhere + @experimentWhereClause + @datasetWhereClause + ' ' + @sqlOrderBy
		Exec (@sqlSelect + ' ' + @sqlFrom + ' ' + @sqlWhere + @experimentWhereClause + @datasetWhereClause + ' ' + @sqlOrderBy)
	end
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows'
	If Len(@pepIdentMethod) > 0
		Set @UsageMessage = @UsageMessage + '; ' + @pepIdentMethod
	
	Exec PostUsageLogEntry 'GetJobDetailsForDB', @DBName, @UsageMessage
	
Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetJobDetailsForDB]  TO [DMS_SP_User]
GO

