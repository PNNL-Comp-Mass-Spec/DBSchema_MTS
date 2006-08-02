SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetAllProteins]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetAllProteins]
GO


CREATE PROCEDURE dbo.GetAllProteins
/****************************************************
**
**	Desc: 
**	Returns complete list of Proteins (aka proteins)
**  for given mass tag database.  Preferably uses
**  the Protein database defined for the mass tag DB to
**  return all Proteins, not just the identified ones.
**  If no Protein DB is defined, then returns the Protein
**  names, sequences, and masses only, and will
**  only return Proteins for which at least one
**  mass tag exists (that's all that will be available).
**        
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @MTDBName				-- Mass tag database name
**	  @outputColumnNameList	-- Optional, comma separated list of column names to limit the output to
**							--   If blank, all columns are returned.  Valid column names:
**							--     Protein_Name, Protein_Description,
**							--     Protein_Location_Start, Protein_Location_Stop
**							--     Protein_Monoisotopic_Mass, Protein_Sequence
**	  @criteriaSql			-- Sql "Where clause compatible" text for filtering ResultSet
**							--   Example: Protein_Monoisotopic_Mass < 10000
**							-- This parameter can contain Protein_Name criteria, but the @criteriaSQL text will get
**							--   AND'd with the @Proteins parameter, if it is defined
**	  @returnRowCount		-- Set to True to return a row count; False to return the Proteins
**	  @message				-- Status/error message output
**	  @Proteins					-- Filter: Comma separated list of Protein Names or list of Protein match criteria containing a wildcard character (%)
**							-- Example: 'Protein1003, Protein1005, Protein1006'
**							--      or: 'Protein100%'
**							--      or: 'Protein1003, Protein1005, Protein100%'
**							--      or: 'Protein1003, Protein100%, Protein1005'
**	  @ProteinDBDefined			-- Output parameter: set to True if an Protein database is defined for this mass tag database, False if not
**
**		Auth: mem
**		Date: 04/7/2004
**            04/12/2004 mem - added validation logic for @MTDBName
**            09/23/2004 grk - changed ORF to Protein
**            09/24/2004 grk - changed T_External_Databases to V_External_Databases
**			  10/23/2004 mem - Added PostUsageLogEntry and call to CleanupTrueFalseParameter
**			  05/13/2005 mem - Now checking for @outputColumnNameList = 'All' and @criteriaSql = 'na'
**			  11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**    
*****************************************************/
	@MTDBName varchar(128) = '',
	@outputColumnNameList varchar(2048) = '',
	@criteriaSql varchar(6000) = '',
	@returnRowCount varchar(32) = 'False',
	@message varchar(512) = '' output,
	@Proteins varchar(7000) = '',
	@ProteinDBDefined varchar(32) = '' output
As
	set nocount on

	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	set @message = ''
	declare @result int
	
	---------------------------------------------------
	-- validate mass tag DB name
	---------------------------------------------------
	Declare @DBNameLookup varchar(256)
	SELECT  @DBNameLookup = MTL_ID
	FROM MT_Main.dbo.T_MT_Database_List
	WHERE (MTL_Name = @MTDBName)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 or @myRowCount <> 1
	begin
		set @message = 'Could not resolve mass tag DB name'
		goto Done
	end

	---------------------------------------------------
	-- Cleanup the input parameters
	---------------------------------------------------

	-- Cleanup the True/False parameters
	Exec CleanupTrueFalseParameter @returnRowCount OUTPUT, 1
	
	-- Validate @outputColumnNameList
	Set @outputColumnNameList = LTrim(RTrim(@outputColumnNameList))
	If IsNull(@outputColumnNameList, '') = '' Or @outputColumnNameList = 'All'
	Begin
		-- Define the default output column list
		Set @outputColumnNameList = ''
		Set @outputColumnNameList = @outputColumnNameList + 'Protein_Name, Protein_Description, '
		Set @outputColumnNameList = @outputColumnNameList + 'Protein_Location_Start, Protein_Location_Stop, '
		Set @outputColumnNameList = @outputColumnNameList + 'Protein_Monoisotopic_Mass, Protein_Sequence'
	End

	---------------------------------------------------
	-- Determine if a valid Protein database is defined
	-- for the selected mass tag database
	-- Lookup the Protein DB name in @MTDBName..V_External_Databases
	---------------------------------------------------

	Declare	@ProteinDBName varchar(255),
			@ProteinDBExists int,
			@MTDBTableName varchar(1024)

	Set @ProteinDBName = ''
	Set @ProteinDBExists = 0
	Set @MTDBTableName = '[' + @MTDBName + ']..V_External_Databases'

	-- We need a temporary table to hold the result of looking up
	-- the Protein DB Name in the mass tag database
	CREATE TABLE #ProteinDBForMTDB (
		Protein_DB_Name varchar (255)
	)   
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Could not create temporary table'
		goto Done
	end

	declare @sql nvarchar(1024)
	--
	set @sql = ''
	set @sql = @sql + ' INSERT INTO #ProteinDBForMTDB'
	set @sql = @sql + ' SELECT TOP 1 Protein_DB_Name'
	set @sql = @sql + ' FROM ' + @MTDBTableName

	exec @result = sp_executesql @sql
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount = 1
	Begin
		-- Obtain the Protein DB from #ProteinDBForMTDB	
		SELECT TOP 1 @ProteinDBName = Protein_DB_Name
		FROM #ProteinDBForMTDB
		--
		If Len(@ProteinDBName) > 0
		Begin
			-- Verify that the database actually exists
			SELECT @ProteinDBExists = Count(*) 
			FROM master..sysdatabases AS SD
			WHERE SD.NAME = @ProteinDBName
		End
	End

	---------------------------------------------------
	-- build the sql query to get the Protein data, either
	-- from the Protein datase or from the mass tag database
	---------------------------------------------------

	Declare @sqlProteinInfo varchar(1024)
	
	Set @sqlProteinInfo = 'SELECT'
	If @ProteinDBExists > 0
	 Begin
		Set @ProteinDBDefined = 'True'
		
		Set @sqlProteinInfo = @sqlProteinInfo + ' Reference AS Protein_Name,'
		Set @sqlProteinInfo = @sqlProteinInfo + ' IsNull(Description_From_FASTA, Reference) AS Protein_Description,'
		Set @sqlProteinInfo = @sqlProteinInfo + ' IsNull(Location_Start,0) AS Protein_Location_Start,'
		Set @sqlProteinInfo = @sqlProteinInfo + ' IsNull(Location_Stop,0) AS Protein_Location_Stop,'
		Set @sqlProteinInfo = @sqlProteinInfo + ' IsNull(Monoisotopic_Mass, 0) AS Protein_Monoisotopic_Mass,'
		Set @sqlProteinInfo = @sqlProteinInfo + ' IsNull(Protein_Sequence, '''') AS Protein_Sequence'
		Set @sqlProteinInfo = @sqlProteinInfo + ' FROM ' + @ProteinDBName + '.dbo.T_ORF'
	 End
	Else
	 Begin
		Set @ProteinDBDefined = 'False'
		
		Set @sqlProteinInfo = @sqlProteinInfo + ' Reference AS Protein_Name,'
		Set @sqlProteinInfo = @sqlProteinInfo + ' Reference AS Protein_Description,'
		Set @sqlProteinInfo = @sqlProteinInfo + ' 0 AS Protein_Location_Start,'
		Set @sqlProteinInfo = @sqlProteinInfo + ' 0 AS Protein_Location_Stop,'
		Set @sqlProteinInfo = @sqlProteinInfo + ' IsNull(Monoisotopic_Mass, 0) AS Protein_Monoisotopic_Mass,'
		Set @sqlProteinInfo = @sqlProteinInfo + ' IsNull(Protein_Sequence, '''') AS Protein_Sequence'
		Set @sqlProteinInfo = @sqlProteinInfo + ' FROM [' + @MTDBName + '].dbo.V_IFC_Proteins'
	 End

	---------------------------------------------------
	-- now build the sql wrapper to only return the 
	-- requested columns
	---------------------------------------------------
	declare @sqlSelect varchar(2048)
	declare @sqlFrom varchar(2048)
	declare @sqlWhere varchar(8000)
	declare @sqlOrderBy varchar(2048)

	-- Construct columns for the Select clause
	-- None of the columns are required, but if @outputColumnNameList
	-- does not contain any valid columns, then Protein_Name will be used
	Set @sqlSelect = ''

	If CharIndex('Protein_Name', @outputColumnNameList) > 0
		Set @sqlSelect = @sqlSelect + ', Protein_Name'

	If CharIndex('Protein_Description', @outputColumnNameList) > 0
		Set @sqlSelect = @sqlSelect + ', Protein_Description'

	If CharIndex('Protein_Location_Start', @outputColumnNameList) > 0
		Set @sqlSelect = @sqlSelect + ', Protein_Location_Start'

	If CharIndex('Protein_Location_Stop', @outputColumnNameList) > 0
		Set @sqlSelect = @sqlSelect + ', Protein_Location_Stop'

	If CharIndex('Protein_Monoisotopic_Mass', @outputColumnNameList) > 0
		Set @sqlSelect = @sqlSelect + ', Protein_Monoisotopic_Mass'

	If CharIndex('Protein_Sequence', @outputColumnNameList) > 0
		Set @sqlSelect = @sqlSelect + ', Protein_Sequence'

	-- Prepend SELECT to @sqlSelect
	If Len(@sqlSelect) = 0
		Set @sqlSelect = 'SELECT Protein_Name'
	Else
		Set @sqlSelect = 'SELECT ' + LTrim(SubString(@sqlSelect, 2, Len(@sqlSelect)))


	-- The From clause simply references @sqlProteinInfo
	Set @sqlFrom = 'FROM (' + @sqlProteinInfo + ') AS ProteinLookupQ'
	
	-- Define the Order By clause
	Set @sqlOrderBy = 'ORDER BY Protein_Name'


	---------------------------------------------------
	-- Parse @Proteins to create a proper SQL where clause containing
	-- a mix of Where xx In ('A','B') and Where xx Like ('C%') statements
	---------------------------------------------------

	Declare @ProteinWhereClause varchar(8000)
	Set @ProteinWhereClause = ''

	Exec ConvertListToWhereClause @Proteins, 'Protein_Name', @entryListWhereClause = @ProteinWhereClause OUTPUT

	-- Construct the base Where clause
	-- Add the Ad Hoc Where criteria, if applicable
	Set @criteriaSql = IsNull(@criteriaSql, '')
	If @criteriaSql = 'na'
		Set @criteriaSql = ''

	If Len(@criteriaSql) > 0
	 Begin
		Set @sqlWhere = 'WHERE (' + @criteriaSql + ')'
		If Len(@ProteinWhereClause) > 0
			Set @sqlWhere = @sqlWhere + ' AND '
	 End
	Else
	 Begin
		If Len(@ProteinWhereClause) > 0
			Set @sqlWhere = 'WHERE '
		Else
			Set @sqlWhere = ''
	 End

	---------------------------------------------------
	-- Obtain the mass tags from the given database
	---------------------------------------------------

	-- We could append @ProteinsWhereClause to @sqlWhere, but the string length
	-- could become too long; thus, we'll add it in when we combine the Sql to Execute
	-- Surround the Protein where clause with parentheses for safety
	If Len(@ProteinWhereClause) > 0
		Set @ProteinWhereClause = '(' + @ProteinWhereClause + ')'
	
	If @returnRowCount = 'true'
		-- In order to return the row count, we wrap the sql text with Count (*) 
		-- and exclude the @sqlOrderBy text from the sql statement
		Exec ('SELECT Count (*) As ResultSet_Row_Count FROM (' + @sqlSelect + ' ' + @sqlFrom + ' ' + @sqlWhere + @ProteinWhereClause + ') As LookupQ')
	Else
		--Print @sqlSelect + ' ' + @sqlFrom + ' ' + @sqlWhere + @ProteinWhereClause + ' ' + @sqlOrderBy
		Exec (@sqlSelect + ' ' + @sqlFrom + ' ' + @sqlWhere + @ProteinWhereClause + ' ' + @sqlOrderBy)
	
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows'
	Exec PostUsageLogEntry 'GetAllProteins', @MTDBName, @UsageMessage


Done:
	return @myError



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetAllProteins]  TO [DMS_SP_User]
GO

