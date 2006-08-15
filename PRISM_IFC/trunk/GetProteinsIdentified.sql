/****** Object:  StoredProcedure [dbo].[GetProteinsIdentified] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetProteinsIdentified
/****************************************************
**
**	Desc: 
**	Returns list of proteins
**  for given match method, experiment(s), and
**  mass tag database
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @MTDBName				-- Mass tag database name
**	  @outputColumnNameList	-- Optional, comma separated list of column names to limit the output to
**							--   If blank, all columns are returned.  Valid column names:
**							--     Experiment, Protein_Name, Mass_Tag_Count,
**							--     MSMS_Observation_Count_Avg, MSMS_High_Normalized_Score_Avg, 
**							--	   MSMS_High_Discriminant_Score_Avg, Mod_Count_Avg,
**							--     Dataset_Count_Avg, and Job_Count_Avg
**							--     In addition, for method UMCPeakMatch(MS-FTICR) only, column: Peak_Matching_Task_Count
**							--   Note that Experiment and Protein_Name will always be displayed, regardless of @outputColumnNameList
**	  @criteriaSql			-- Sql "Where clause compatible" text for filtering ResultSet
**							--   Example: Mass_Tag_Count >= 5 Or Dataset_Count >= 3
**							-- Although this parameter can contain Protein_Name criteria, it is better to filter for Proteins using the @Proteins parameter
**	  @returnRowCount		-- Set to True to return a row count; False to return the Proteins
**	  @message				-- Status/error message output
**	  @pepIdentMethod		-- Can be DBSearch(MS/MS-LCQ) or UMCPeakMatch(MS-FTICR)
**	  @experiments			-- Filter: Comma separated list of experiments or list of experiment match criterion containing a wildcard character(%)
**							--   Names do not need single quotes around them; see @Proteins entry for examples
**	  @Proteins				-- Filter: Comma separated list of Protein Names or list of Protein match criteria containing a wildcard character (%)
**							-- Example: 'Protein1003, Protein1005, Protein1006'
**							--      or: 'Protein100%'
**							--      or: 'Protein1003, Protein1005, Protein100%'
**							--      or: 'Protein1003, Protein100%, Protein1005'
**	  @maximumRowCount		-- Maximum number of rows to return; set to 0 or a negative number to return all rows; Default is 100,000 rows
**	  @includeSupersededData	-- Set to True to include Proteins from "Superseded" peak matching tasks; only applicable for method UMCPeakMatch(MS-FTICR)
**	  @minimumPMTQualityScore	-- Set to 0 to include all Proteins, including those with low quality mass tags
**
**	Auth:	mem, grk
**	Date:	09/20/2004 grk - cloned from GetORFsIdentified and modified to use V_IFC_* views for protein tables
**			10/18/2004 mem - Now returning complete row count if @returnRowCount is true
**			10/23/2004 mem - Added PostUsageLogEntry and call to CleanupTrueFalseParameter
**			10/28/2004 mem - Fixed computation of Mass_Tag_Count, added two columns (High_Discriminant_Score_Avg and Mod_Count_Avg), and changed the Dataset_Count and Job_Count columns to Dataset_Count_Avg and Job_Count_Avg
**			02/09/2005 mem - Now rounding High Normalized Score to 3 decimal places and High Discriminant Score to 4 decimal places
**			05/13/2005 mem - Now checking for @outputColumnNameList = 'All' and @criteriaSql = 'na'
**			11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**			02/20/2006 mem - Now validating that @MTDBName has a state less than 100 in MT_Main
**    
*****************************************************/
(
	@MTDBName varchar(128) = '',
	@outputColumnNameList varchar(2048) = '',
	@criteriaSql varchar(6000) = '',
	@returnRowCount varchar(32) = 'True',
	@message varchar(512) = '' output,
	@pepIdentMethod varchar(32) = 'DBSearch(MS/MS-LCQ)',
	@experiments varchar(7000) = '',
	@Proteins varchar(7000) = '',
	@maximumRowCount int = 100000,
	@includeSupersededData varchar(32) = 'False',
	@minimumPMTQualityScore float = 1.0
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''
	declare @result int
	
	---------------------------------------------------
	-- validate mass tag DB name
	---------------------------------------------------
	Declare @DBNameLookup varchar(256)
	SELECT  @DBNameLookup = MTL_ID
	FROM MT_Main.dbo.T_MT_Database_List
	WHERE (MTL_Name = @MTDBName) AND MTL_State < 100
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 or @myRowCount <> 1
	begin
		set @message = 'Could not resolve mass tag DB name'
		goto Done
	end

	---------------------------------------------------
	-- resolve match method name to internal code
	---------------------------------------------------
	declare @internalMatchCode varchar(32)
	set @internalMatchCode = ''
	--
	SELECT @internalMatchCode = Internal_Code
	FROM T_Match_Methods
	WHERE ([Name] = @pepIdentMethod)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 or @internalMatchCode = ''
	begin
		set @message = 'Could not resolve match methods'
		goto Done
	end


	---------------------------------------------------
	-- Determine the DB Schema Version
	---------------------------------------------------
	Declare @DB_Schema_Version real
	Set @DB_Schema_Version = 1

	-- Lookup the DB Schema Version
	Exec GetDBSchemaVersionByDBName @MTDBName, @DB_Schema_Version OUTPUT


	---------------------------------------------------
	-- Cleanup the input parameters
	---------------------------------------------------

	-- Cleanup the True/False parameters
	Exec CleanupTrueFalseParameter @returnRowCount OUTPUT, 1
	Exec CleanupTrueFalseParameter @includeSupersededData OUTPUT, 0
	
	-- We need to replace the user-friendly column names in @criteriaSql with the official column names
	-- The results of the replacement will go in @criteriaSqlUpdated
	Declare @criteriaSqlUpdated varchar(7000)
	Set @criteriaSqlUpdated = IsNull(@criteriaSql, '')
	If @criteriaSqlUpdated = 'na'
		Set @criteriaSqlUpdated = ''

	-- Note that the Replace function is not case sensitive
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'Mass_Tag_Count', 'COUNT(StatsQ.Mass_Tag_ID)')
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'MSMS_Observation_Count_Avg', 'AVG(MT.Number_Of_Peptides)')
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'MSMS_High_Normalized_Score_Avg', 'AVG(MT.High_Normalized_Score)')
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'MSMS_High_Discriminant_Score_Avg', 'AVG(MT.High_Discriminant_Score)')
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'Mod_Count_Avg', 'AVG(CONVERT(float, MT.Mod_Count))')
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'Dataset_Count_Avg', 'AVG(StatsQ.Dataset_Count)')
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'Job_Count_Avg', 'AVG(StatsQ.Job_Count')

	If @internalMatchCode = 'UMC'
	Begin
		Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'Peak_Matching_Task_Count', 'COUNT(DISTINCT MMD.MD_ID)')
		--Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'UMC_Hit_Count', 'COUNT(URD.UMC_ResultDetails_ID)')
		--Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'MT_Abundance', 'SUM(FUR.Class_Abundance)')
	End

	-- Validate @outputColumnNameList
	Set @outputColumnNameList = LTrim(RTrim(@outputColumnNameList))
	If IsNull(@outputColumnNameList, '') = '' Or @outputColumnNameList = 'All'
	Begin
		-- Define the default output column list
		Set @outputColumnNameList = ''
		Set @outputColumnNameList = @outputColumnNameList + 'Experiment, Protein_Name, Mass_Tag_Count, '
		Set @outputColumnNameList = @outputColumnNameList + 'MSMS_Observation_Count_Avg, MSMS_High_Normalized_Score_Avg, '
		
		If @DB_Schema_Version >= 2
			Set @outputColumnNameList = @outputColumnNameList + 'MSMS_High_Discriminant_Score_Avg, Mod_Count_Avg, '

		Set @outputColumnNameList = @outputColumnNameList + 'Dataset_Count_Avg, Job_Count_Avg'

		If @internalMatchCode = 'UMC'
		Begin
			Set @outputColumnNameList = @outputColumnNameList + 'Peak_Matching_Task_Count'
			--Set @outputColumnNameList = @outputColumnNameList + 'UMC_Hit_Count'
			--Set @outputColumnNameList = @outputColumnNameList + 'MT_Abundance'
		End
	End

	-- Force @maximumRowCount to be negative if @returnRowCount is true
	If @returnRowCount = 'true'
		Set @maximumRowCount = -1

	---------------------------------------------------
	-- build the sql query to get Protein data
	---------------------------------------------------
	declare @sqlSelect varchar(2048)
	declare @sqlStatsQ varchar(4096)
	declare @sqlStatsQWhere varchar(2048)
	declare @sqlFrom varchar(2048)
	declare @sqlWhere varchar(8000)
	declare @sqlGroupBy varchar(2048)
	declare @sqlHaving varchar(8000)
	declare @sqlOrderBy varchar(2048)

	-- Construct the base Select clause, optionally limiting the number of rows
	Set @sqlSelect = ''
	If IsNull(@maximumRowCount,-1) <= 0
		Set @sqlSelect = @sqlSelect + 'SELECT'
	Else
		Set @sqlSelect = @sqlSelect + 'SELECT TOP ' + Cast(@maximumRowCount as varchar(9))
		
	
	-- Note that the Experiment and Protein_Name columns must be present in the output
	Set @sqlSelect = @sqlSelect + ' Experiment, Protein_Name'
	

	-- Add the optional columns to the Select clause
	If CharIndex('Mass_Tag_Count', @outputColumnNameList) > 0 OR CharIndex('Mass_Tag_Count', @criteriaSql) > 0
		Set @sqlSelect = @sqlSelect + ', COUNT(StatsQ.Mass_Tag_ID) AS Mass_Tag_Count'

	If CharIndex('MSMS_Observation_Count_Avg', @outputColumnNameList) > 0 OR CharIndex('MSMS_Observation_Count_Avg', @criteriaSql) > 0
		Set @sqlSelect = @sqlSelect + ', AVG(MT.Number_Of_Peptides) AS MSMS_ObservationCount_Avg'
		
	If CharIndex('MSMS_High_Normalized_Score_Avg', @outputColumnNameList) > 0 OR CharIndex('MSMS_High_Normalized_Score_Avg', @criteriaSql) > 0
		Set @sqlSelect = @sqlSelect + ', Round(AVG(MT.High_Normalized_Score), 3) AS MSMS_High_Normalized_Score_Avg'


	If @DB_Schema_Version < 2
	Begin
		-- Check for invalid column names for this schema version
		If CharIndex('MSMS_High_Discriminant_Score_Avg', @criteriaSql) > 0 OR
		   CharIndex('Mod_Count_Avg', @criteriaSql) > 0
		Begin
			set @message = 'One or more column names in @criteriaSql is not valid for the given database (old schema version)'
			goto Done
		End
	End
	Else
	Begin
		If CharIndex('MSMS_High_Discriminant_Score_Avg', @outputColumnNameList) > 0 OR CharIndex('MSMS_High_Discriminant_Score_Avg', @criteriaSql) > 0
			Set @sqlSelect = @sqlSelect + ', Round(AVG(MT.High_Discriminant_Score), 4) AS MSMS_High_Discriminant_Score_Avg'

		If CharIndex('Mod_Count_Avg', @outputColumnNameList) > 0 OR CharIndex('Mod_Count_Avg', @criteriaSql) > 0
			Set @sqlSelect = @sqlSelect + ', AVG(Convert(float, MT.Mod_Count)) AS Mod_Count_Avg'
	End
			
	If CharIndex('Dataset_Count_Avg', @outputColumnNameList) > 0 OR CharIndex('Dataset_Count_Avg', @criteriaSql) > 0
		Set @sqlSelect = @sqlSelect + ', AVG(StatsQ.Dataset_Count) AS Dataset_Count_Avg'

	If CharIndex('Job_Count_Avg', @outputColumnNameList) > 0 OR CharIndex('Job_Count_Avg', @criteriaSql) > 0
		Set @sqlSelect = @sqlSelect + ', AVG(StatsQ.Job_Count) AS Job_Count_Avg'


	-- Define the Sql for the inner query (StatsQ)
	Set @sqlStatsQ = '(SELECT'
	Set @sqlStatsQ = @sqlStatsQ + ' JobTable.Experiment'
	Set @sqlStatsQ = @sqlStatsQ + ', RefTable.Reference AS Protein_Name'
	Set @sqlStatsQ = @sqlStatsQ + ', MT.Mass_Tag_ID'
	Set @sqlStatsQ = @sqlStatsQ + ', COUNT(DISTINCT Dataset) AS Dataset_Count'
	Set @sqlStatsQ = @sqlStatsQ + ', COUNT(DISTINCT Job) AS Job_Count'

	-- The following optional columns only apply to Proteins from UMC peak matching data
	If @internalMatchCode = 'UMC'
	Begin
		If CharIndex('Peak_Matching_Task_Count', @outputColumnNameList) > 0 OR CharIndex('Peak_Matching_Task_Count', @criteriaSql) > 0
			Set @sqlStatsQ = @sqlStatsQ + ', COUNT(DISTINCT MMD.MD_ID) AS Peak_Matching_Task_Count'

--		If CharIndex('UMC_Hit_Count', @outputColumnNameList) > 0 OR CharIndex('UMC_Hit_Count', @criteriaSql) > 0
--			Set @sqlStatsQ = @sqlStatsQ + ', COUNT(URD.UMC_ResultDetails_ID) AS UMC_Hit_Count'
--		If CharIndex('MT_Abundance', @outputColumnNameList) > 0 OR CharIndex('MT_Abundance', @criteriaSql) > 0
--			Set @sqlStatsQ = @sqlStatsQ + ', SUM(FUR.Class_Abundance) AS MT_Abundance'

	End

	-- Construct the From and Where clauses for the inner query
	Set @sqlStatsQ = @sqlStatsQ + ' FROM'

	Set @sqlStatsQWhere = ' WHERE'
	Set @sqlStatsQWhere = @sqlStatsQWhere + ' (JobTable.State <> 5) AND '				-- Exclude jobs marked as "No Interest"
	Set @sqlStatsQWhere = @sqlStatsQWhere + ' (IsNull(MT.PMT_Quality_Score,0) >= ' + Cast(@minimumPMTQualityScore as varchar(9)) + ')'


	If @internalMatchCode = 'PMT'
	Begin
		Set @sqlStatsQ = @sqlStatsQ + ' SOURCEJOBTABLE AS JobTable INNER JOIN'
		Set @sqlStatsQ = @sqlStatsQ + ' DATABASE..T_Peptides AS PT ON JobTable.Job = PT.Analysis_ID INNER JOIN'
		Set @sqlStatsQ = @sqlStatsQ + ' DATABASE..V_IFC_Mass_Tag_To_Protein_Map AS MTO INNER JOIN'
		Set @sqlStatsQ = @sqlStatsQ + ' DATABASE..T_Mass_Tags AS MT ON MTO.Mass_Tag_ID = MT.Mass_Tag_ID INNER JOIN'
		Set @sqlStatsQ = @sqlStatsQ + ' DATABASE..V_IFC_Proteins AS RefTable ON MTO.Ref_ID = RefTable.Ref_ID'
		Set @sqlStatsQ = @sqlStatsQ + ' ON PT.Mass_Tag_ID = MT.Mass_Tag_ID'
	End

	If @internalMatchCode = 'UMC'
	Begin
		Set @sqlStatsQ = @sqlStatsQ + ' DATABASE..T_FTICR_UMC_ResultDetails AS URD INNER JOIN'
		Set @sqlStatsQ = @sqlStatsQ + ' DATABASE..T_FTICR_UMC_Results AS FUR ON URD.UMC_Results_ID = FUR.UMC_Results_ID INNER JOIN'
		Set @sqlStatsQ = @sqlStatsQ + ' DATABASE..T_Match_Making_Description AS MMD ON FUR.MD_ID = MMD.MD_ID INNER JOIN'
		Set @sqlStatsQ = @sqlStatsQ + ' SOURCEJOBTABLE AS JobTable ON MMD.MD_Reference_Job = JobTable.Job INNER JOIN'
		Set @sqlStatsQ = @sqlStatsQ + ' DATABASE..T_Mass_Tags AS MT ON URD.Mass_Tag_ID = MT.Mass_Tag_ID INNER JOIN'
		Set @sqlStatsQ = @sqlStatsQ + ' DATABASE..V_IFC_Mass_Tag_To_Protein_Map AS MTO ON MT.Mass_Tag_ID = MTO.Mass_Tag_ID INNER JOIN'
		Set @sqlStatsQ = @sqlStatsQ + ' DATABASE..V_IFC_Proteins AS RefTable ON MTO.Ref_ID = RefTable.Ref_ID'

		Set @sqlStatsQWhere = @sqlStatsQWhere + ' AND (MMD.MD_Type = 1)'				-- Normal peak matching tasks only (not pairs)
		Set @sqlStatsQWhere = @sqlStatsQWhere + ' AND (URD.Match_State = 6)'			-- Rows marked as "Hits" only
		
		If @includeSupersededData = 'true'
			Set @sqlStatsQWhere = @sqlStatsQWhere + ' AND (MMD.MD_State IN (2, 5))'		-- Allow normal and superseded peak matching tasks
		Else
			Set @sqlStatsQWhere = @sqlStatsQWhere + ' AND (MMD.MD_State = 2)'			-- Normal peak matching tasks only
	End

	Set @sqlStatsQ = @sqlStatsQ + @sqlStatsQWhere
    Set @sqlStatsQ = @sqlStatsQ + ' GROUP BY JobTable.Experiment, RefTable.Reference, MT.Mass_Tag_ID'
    Set @sqlStatsQ = @sqlStatsQ + ') As StatsQ'

	---------------------------------------------------
	-- Customize the database name and Job table name
	-- for the specific MTDB and match method
	---------------------------------------------------

	if @internalMatchCode = 'PMT'
	begin
		set @sqlStatsQ = replace(@sqlStatsQ, 'SOURCEJOBTABLE', @MTDBName + '..T_Analysis_Description')
		set @sqlStatsQ = replace(@sqlStatsQ, 'DATABASE..', '[' + @MTDBName + ']..')
	end

	if @internalMatchCode = 'UMC'
	begin
		set @sqlStatsQ = replace(@sqlStatsQ, 'SOURCEJOBTABLE', @MTDBName + '..T_FTICR_Analysis_Description')
		set @sqlStatsQ = replace(@sqlStatsQ, 'DATABASE..', '[' + @MTDBName + ']..')
	end


	-- Construct the From clause for the outer query
	Set @sqlFrom = ''
	Set @sqlFrom = @sqlFrom + ' FROM ' + @sqlStatsQ + ' INNER JOIN'
	Set @sqlFrom = @sqlFrom + ' DATABASE..T_Mass_Tags AS MT ON StatsQ.Mass_Tag_ID = MT.Mass_Tag_ID'

	-- Construct the base Group By clause
    Set @sqlGroupBy = 'GROUP BY StatsQ.Experiment, StatsQ.Protein_Name'
		

	-- Add the Ad Hoc Where criteria, if applicable
	-- Since the majority of the Ad Hoc criteria involve aggregate functions,
	-- we will always insert them into a Having clause,
	Set @sqlHaving = ''
	If Len(@criteriaSqlUpdated) > 0
		Set @sqlHaving = 'HAVING (' + @criteriaSqlUpdated + ')'

	-- Define the Order By clause
	Set @sqlOrderBy = 'ORDER BY  StatsQ.Experiment, StatsQ.Protein_Name'


	---------------------------------------------------
	-- Customize the database name and Job table name
	-- for the specific MTDB and match method
	---------------------------------------------------

	set @sqlFrom = replace(@sqlFrom, 'DATABASE..', '[' + @MTDBName + ']..')

	---------------------------------------------------
	-- Parse @experiments and @Proteins to create a proper
	-- SQL where clause containing a mix of 
	-- Where xx In ('A','B') and Where xx Like ('C%') statements
	---------------------------------------------------

	Declare @experimentWhereClause varchar(8000),
			@ProteinWhereClause varchar(8000)
	Set @experimentWhereClause = ''
	Set @ProteinWhereClause = ''

	Exec ConvertListToWhereClause @experiments, 'StatsQ.Experiment', @entryListWhereClause = @experimentWhereClause OUTPUT
	Exec ConvertListToWhereClause @Proteins, 'StatsQ.Protein_Name', @entryListWhereClause = @ProteinWhereClause OUTPUT

	---------------------------------------------------
	-- Obtain the Proteins from the given database
	---------------------------------------------------
	
	-- We could append @experimentWhereClause and @ProteinWhereClause to @sqlWhere, but the string length
	-- could become too long; thus, we'll add it in when we combine the Sql to Execute
	-- However, we need to prepend them with AND

	If Len(@experimentWhereClause) > 0 OR Len(@ProteinWhereClause) > 0
	Begin
		Set @sqlWhere = 'WHERE'
		
		If Len(@experimentWhereClause) > 0
			Set @experimentWhereClause = ' (' + @experimentWhereClause + ')'

		If Len(@ProteinWhereClause) > 0
		Begin
			Set @ProteinWhereClause = ' (' + @ProteinWhereClause + ')'
			
			If Len(@experimentWhereClause) > 0
				Set @ProteinWhereClause = ' AND (' + @ProteinWhereClause + ')'
		End

	End
	Else
		Set @sqlWhere = ''
		

	-- DEBUG
	-- save dynamic query text
	--
	--INSERT INTO T_Junk(Contents) VALUES(@sqlSelect + ' ' + @sqlFrom + ' ' + @sqlWhere + @experimentWhereClause + @ProteinWhereClause + ' ' + @sqlGroupBy + ' ' + @sqlHaving + ' ' + @sqlOrderBy)	

	If @returnRowCount = 'true'
		-- In order to return the row count, we wrap the sql text with Count (*) 
		-- and exclude the @sqlOrderBy text from the sql statement
		Exec ('SELECT Count (*) As ResultSet_Row_Count FROM (' + @sqlSelect + ' ' + @sqlFrom + ' ' + @sqlWhere + @experimentWhereClause + @ProteinWhereClause + ' ' + @sqlGroupBy + ' ' + @sqlHaving + ') As LookupQ')
	Else
		--Print  @sqlSelect + ' ' + @sqlFrom + ' ' + @sqlWhere + @experimentWhereClause + @ProteinWhereClause + ' ' + @sqlGroupBy + ' ' + @sqlHaving + ' ' + @sqlOrderBy
		Exec (@sqlSelect + ' ' + @sqlFrom + ' ' + @sqlWhere + @experimentWhereClause + @ProteinWhereClause + ' ' + @sqlGroupBy + ' ' + @sqlHaving + ' ' + @sqlOrderBy)
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows; ' + @pepIdentMethod
	Exec PostUsageLogEntry 'GetProteinsIdentified', @MTDBName, @UsageMessage
	
Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[GetProteinsIdentified] TO [DMS_SP_User]
GO
