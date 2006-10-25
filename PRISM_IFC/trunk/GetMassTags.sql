/****** Object:  StoredProcedure [dbo].[GetMassTags] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetMassTags
/****************************************************
**
**	Desc: 
**	Returns list of mass tags (PMTs or UMC matches)
**  for given match method, experiment(s), and 
**	mass tag database
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @MTDBName				-- Mass tag database name
**	  @outputColumnNameList	-- Optional, comma separated list of column names to limit the output to
**							--   If blank, all columns are returned.  Valid column names:
**							--     Experiment, Protein_Name, Mass_Tag_ID, Mass_Tag_Name, Peptide_Sequence, Peptide_Monoisotopic_Mass, 
**							--     MSMS_Observation_Count, MSMS_High_Normalized_Score, MSMS_DeltaCn2_Maximum, MSMS_High_Discriminant_Score,
**							--     PMT_Quality_Score, Cleavage_State_Name, Residue_Start, Residue_End, Dataset_Count, and Job_Count
**							--     In addition, for method UMCPeakMatch(MS-FTICR) only, columns: Peak_Matching_Task_Count, SLiC_Score_Maximum, and MT_Abundance_Avg
**							--   Note that Experiment, Protein_Name, and Mass_Tag_ID will always be displayed, regardless of @outputColumnNameList
**	  @criteriaSql			-- Sql "Where clause compatible" text for filtering ResultSet
**							--   Example: Protein_Name Like 'DR2%' And (MSMS_High_Normalized_Score >= 5 Or MSMS_Observation_Count >= 10)
**							-- Although this parameter can contain Protein_Name criteria, it is better to filter for Proteins using the @Proteins parameter
**	  @returnRowCount		-- Set to True to return a row count; False to return the mass tags
**	  @message				-- Status/error message output
**	  @pepIdentMethod		-- Can be DBSearch(MS/MS-LCQ) or UMCPeakMatch(MS-FTICR)
**	  @experiments			-- Filter: Comma separated list of experiments or list of experiment match criteria containing a wildcard character(%)
**							--   Names do not need single quotes around them; see @Proteins parameter for examples
**	  @Proteins				-- Filter: Comma separated list of Protein Names or list of Protein match criteria containing a wildcard character (%)
**							-- Example: 'Protein1003, Protein1005, Protein1006'
**							--      or: 'Protein100%'
**							--      or: 'Protein1003, Protein1005, Protein100%'
**							--      or: 'Protein1003, Protein100%, Protein1005'
**	  @maximumRowCount		-- Maximum number of rows to return; set to 0 or a negative number to return all rows; Default is 100,000 rows
**	  @includeSupersededData	-- Set to True to include mass tags from "Superseded" peak matching tasks; only applicable for method UMCPeakMatch(MS-FTICR)
**	  @minimumPMTQualityScore	-- Set to 0 to include all mass tags, including low quality mass tags
**
**	Auth:	mem, grk
**	Date:	09/20/2004 grk - cloned from GetMassTags and modified to use V_IFC_* views for protein tables
**			09/23/2004 grk - replaced ORF with Protein
**			10/18/2004 mem - Now returning complete row count if @returnRowCount is true
**			10/23/2004 mem - Added PostUsageLogEntry and call to CleanupTrueFalseParameter
**			10/27/2004 mem - Added three columns (MSMS_High_Discriminant_Score, & MT.Mod_Count, MT.Mod_Description)
**			02/09/2005 mem - Now rounding High Normalized Score to 3 decimal places and High Discriminant Score to 4 decimal places
**			03/09/2005 mem - Now customizing the Job Count and Dataset Count columns with MS or MSMS depending on @pepIdentMethod
**						   - Renamed output column MT_Abundance_Total to MT_Abundance_Avg, and switched from Sum() to Avg() when rolling up abundance
**						   - Added output column SLiC_Score_Maximum (only applies to UMC mode)
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
	-- Determine the DB Schema Version
	---------------------------------------------------
	Declare @DB_Schema_Version real
	Set @DB_Schema_Version = 1

	-- Lookup the DB Schema Version
	-- Note that GetDBSchemaVersionByDBName returns the integer portion of the schema version, and not an error code
	Exec GetDBSchemaVersionByDBName @MTDBName, @DB_Schema_Version OUTPUT


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
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'Protein_Name', 'RefTable.Reference')
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'Peptide_Sequence', 'MT.Peptide')
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'Peptide_Monoisotopic_Mass', 'MT.Monoisotopic_Mass')
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'MSMS_Observation_Count', 'MT.Number_Of_Peptides')
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'MSMS_High_Normalized_Score', 'MT.High_Normalized_Score')
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'MSMS_DeltaCn2_Maximum', 'Max(SS.DeltaCn2)')
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'MSMS_High_Discriminant_Score', 'MT.High_Discriminant_Score')
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'Mod_Count', 'MT.Mod_Count')
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'Mod_Description', 'MT.Mod_Description')
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'Dataset_Count', 'COUNT(DISTINCT JobTable.Dataset)')
	Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'Job_Count', 'COUNT(DISTINCT JobTable.Job)')

	If @internalMatchCode = 'UMC'
	Begin
		Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'Peak_Matching_Task_Count', 'COUNT(DISTINCT MMD.MD_ID)')
		Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'SLiC_Score_Maximum', 'MAX(URD.Match_Score)')
		
		--Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'UMC_Hit_Count', 'COUNT(URD.UMC_ResultDetails_ID)')
		Set @criteriaSqlUpdated = Replace(@criteriaSqlUpdated, 'MT_Abundance_Avg', 'Round(AVG(FUR.Class_Abundance), 0)')
	End

	-- Validate @outputColumnNameList
	Set @outputColumnNameList = LTrim(RTrim(@outputColumnNameList))
	If IsNull(@outputColumnNameList, '') = '' Or @outputColumnNameList = 'All'
	Begin
		-- Define the default output column list
		Set @outputColumnNameList = ''
		Set @outputColumnNameList = @outputColumnNameList + 'Experiment, Protein_Name, Mass_Tag_ID, Mass_Tag_Name, '
		Set @outputColumnNameList = @outputColumnNameList + 'Peptide_Sequence, Peptide_Monoisotopic_Mass, '
		Set @outputColumnNameList = @outputColumnNameList + 'MSMS_Observation_Count, MSMS_High_Normalized_Score, '

		If @DB_Schema_Version >= 2
		Begin
			if @internalMatchCode <> 'UMC'
				Set @outputColumnNameList = @outputColumnNameList + 'MSMS_DeltaCn2_Maximum, '
			
			Set @outputColumnNameList = @outputColumnNameList + 'MSMS_High_Discriminant_Score, '
			Set @outputColumnNameList = @outputColumnNameList + 'Mod_Count, Mod_Description, '
		End
		
		Set @outputColumnNameList = @outputColumnNameList + 'PMT_Quality_Score, Cleavage_State_Name, '
		Set @outputColumnNameList = @outputColumnNameList + 'Residue_Start, Residue_End, '
		
		if @internalMatchCode = 'UMC'
			Set @outputColumnNameList = @outputColumnNameList + 'MS_Dataset_Count, MS_Job_Count'
		else
			Set @outputColumnNameList = @outputColumnNameList + 'MSMS_Dataset_Count, MSMS_Job_Count'

		If @internalMatchCode = 'UMC'
		Begin
			Set @outputColumnNameList = @outputColumnNameList + ', Peak_Matching_Task_Count'
			Set @outputColumnNameList = @outputColumnNameList + ', SLiC_Score_Maximum'
			Set @outputColumnNameList = @outputColumnNameList + ', MT_Abundance_Avg'
			--Set @outputColumnNameList = @outputColumnNameList + ', UMC_Hit_Count'
		End
	End

	-- Force @maximumRowCount to be negative if @returnRowCount is true
	If @returnRowCount = 'true'
		Set @maximumRowCount = -1

	---------------------------------------------------
	-- build the sql query to get mass tag data
	---------------------------------------------------
	declare @sqlSelect varchar(2048)
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
		
	-- Note that the Experiment, Protein_Name, and Mass_Tag_ID columns must be present in the output
	Set @sqlSelect = @sqlSelect + ' JobTable.Experiment'
	Set @sqlSelect = @sqlSelect + ', RefTable.Reference AS Protein_Name'
    Set @sqlSelect = @sqlSelect + ', MT.Mass_Tag_ID'
	
	-- Construct the base Group By clause
    Set @sqlGroupBy = 'GROUP BY JobTable.Experiment, RefTable.Reference, MT.Mass_Tag_ID'

	-- Add the optional columns to the Select clause and Group By clause
	If CharIndex('Mass_Tag_Name', @outputColumnNameList) > 0
	Begin
		Set @sqlSelect = @sqlSelect + ', MTO.Mass_Tag_Name'
		Set @sqlGroupBy = @sqlGroupBy + ', MTO.Mass_Tag_Name'
	End
		
	If CharIndex('Peptide_Sequence', @outputColumnNameList) > 0
	Begin
		Set @sqlSelect = @sqlSelect + ', MT.Peptide AS Peptide_Sequence'
		Set @sqlGroupBy = @sqlGroupBy + ', MT.Peptide'
	End
		
	If CharIndex('Peptide_Monoisotopic_Mass', @outputColumnNameList) > 0
	Begin
		Set @sqlSelect = @sqlSelect + ', Round(MT.Monoisotopic_Mass,4) AS Peptide_Monoisotopic_Mass'
		Set @sqlGroupBy = @sqlGroupBy + ', Round(MT.Monoisotopic_Mass,4)'
	End
		
	If CharIndex('MSMS_Observation_Count', @outputColumnNameList) > 0
	Begin
		Set @sqlSelect = @sqlSelect + ', MT.Number_Of_Peptides AS MSMS_Observation_Count'
		Set @sqlGroupBy = @sqlGroupBy + ', MT.Number_Of_Peptides'
	End
		
	If CharIndex('MSMS_High_Normalized_Score', @outputColumnNameList) > 0
	Begin
		Set @sqlSelect = @sqlSelect + ', Round(MT.High_Normalized_Score, 3) AS MSMS_High_Normalized_Score'
		Set @sqlGroupBy = @sqlGroupBy + ', Round(MT.High_Normalized_Score, 3)'
	End


	-- Note: Do not display DeltaCn2 if DB Schema Version is < 2, since the DeltaCn value in that version is not the same as DeltaCn2
	If @DB_Schema_Version >= 2 AND @internalMatchCode <> 'UMC'
	Begin
		If CharIndex('MSMS_DeltaCn2_Maximum', @outputColumnNameList) > 0
			Begin
				Set @sqlSelect = @sqlSelect + ', Max(SS.DeltaCn2) AS MSMS_DeltaCn2_Maximum'
			End
	End
	
	
	If @DB_Schema_Version < 2
	Begin
		-- Check for invalid column names for this schema version
		If CharIndex('MSMS_High_Discriminant_Score_Avg', @criteriaSql) > 0 OR
		   CharIndex('Mod_Count', @criteriaSql) > 0 OR
		   CharIndex('Mod_Description', @criteriaSql) > 0
		Begin
			set @message = 'One or more column names in @criteriaSql is not valid for the given database (old schema version)'
			goto Done
		End		
	End
	Else
	Begin
		If CharIndex('MSMS_High_Discriminant_Score', @outputColumnNameList) > 0
		Begin
			Set @sqlSelect = @sqlSelect + ', Round(MT.High_Discriminant_Score, 4) AS MSMS_High_Discriminant_Score'
			Set @sqlGroupBy = @sqlGroupBy + ', Round(MT.High_Discriminant_Score, 4)'
		End

		If CharIndex('Mod_Count', @outputColumnNameList) > 0
		Begin
			Set @sqlSelect = @sqlSelect + ', MT.Mod_Count AS Mod_Count'
			Set @sqlGroupBy = @sqlGroupBy + ', MT.Mod_Count'
		End

		If CharIndex('Mod_Description', @outputColumnNameList) > 0
		Begin
			Set @sqlSelect = @sqlSelect + ', MT.Mod_Description AS Mod_Description'
			Set @sqlGroupBy = @sqlGroupBy + ', MT.Mod_Description'
		End
	End
			
	If CharIndex('PMT_Quality_Score', @outputColumnNameList) > 0
	Begin
		Set @sqlSelect = @sqlSelect + ', MT.PMT_Quality_Score'
		Set @sqlGroupBy = @sqlGroupBy + ', MT.PMT_Quality_Score'
	End

	If CharIndex('Cleavage_State_Name', @outputColumnNameList) > 0
	Begin
		Set @sqlSelect = @sqlSelect + ', CSN.Cleavage_State_Name'
		Set @sqlGroupBy = @sqlGroupBy + ', CSN.Cleavage_State_Name'
	End
	
	If CharIndex('Residue_Start', @outputColumnNameList) > 0
	Begin
		Set @sqlSelect = @sqlSelect + ', MTO.Residue_Start'
		Set @sqlGroupBy = @sqlGroupBy + ', MTO.Residue_Start'
	End

	If CharIndex('Residue_End', @outputColumnNameList) > 0
	Begin
		Set @sqlSelect = @sqlSelect + ', MTO.Residue_End'
		Set @sqlGroupBy = @sqlGroupBy + ', MTO.Residue_End'
	End
	
	If CharIndex('Dataset_Count', @outputColumnNameList) > 0 OR CharIndex('Dataset_Count', @criteriaSql) > 0
	Begin
		if @internalMatchCode = 'UMC'
			Set @sqlSelect = @sqlSelect + ', COUNT(DISTINCT JobTable.Dataset) AS MS_Dataset_Count'
		else
			Set @sqlSelect = @sqlSelect + ', COUNT(DISTINCT JobTable.Dataset) AS MSMS_Dataset_Count'
	End

	If CharIndex('Job_Count', @outputColumnNameList) > 0 OR CharIndex('Job_Count', @criteriaSql) > 0
	Begin
		if @internalMatchCode = 'UMC'
			Set @sqlSelect = @sqlSelect + ', COUNT(DISTINCT JobTable.Job) AS MS_Job_Count'
		else
			Set @sqlSelect = @sqlSelect + ', COUNT(DISTINCT JobTable.Job) AS MSMS_Job_Count'
	End
	
	-- The following optional columns only apply to mass tags from UMC peak matching data
	If @internalMatchCode = 'UMC'
	Begin
		If CharIndex('Peak_Matching_Task_Count', @outputColumnNameList) > 0 OR CharIndex('Peak_Matching_Task_Count', @criteriaSql) > 0
			Set @sqlSelect = @sqlSelect + ', COUNT(DISTINCT MMD.MD_ID) AS Peak_Matching_Task_Count'

		If CharIndex('SLiC_Score_Maximum', @outputColumnNameList) > 0 OR CharIndex('SLiC_Score_Maximum', @criteriaSql) > 0
			Set @sqlSelect = @sqlSelect + ', MAX(URD.Match_Score) AS SLiC_Score_Maximum'

--		If CharIndex('UMC_Hit_Count', @outputColumnNameList) > 0 OR CharIndex('UMC_Hit_Count', @criteriaSql) > 0
--			Set @sqlSelect = @sqlSelect + ', COUNT(URD.UMC_ResultDetails_ID) AS UMC_Hit_Count'
		If CharIndex('MT_Abundance_Avg', @outputColumnNameList) > 0 OR CharIndex('MT_Abundance_Avg', @criteriaSql) > 0
			Set @sqlSelect = @sqlSelect + ', Round(AVG(FUR.Class_Abundance), 0) AS MT_Abundance_Avg'

	End

	-- Construct the From and Where clauses
	Set @sqlFrom = 'FROM'
	Set @sqlWhere = 'WHERE'
	Set @sqlWhere = @sqlWhere + ' (JobTable.State <> 5) AND '				-- Exclude jobs marked as "No Interest"
	Set @sqlWhere = @sqlWhere + ' (IsNull(MT.PMT_Quality_Score,0) >= ' + Cast(@minimumPMTQualityScore as varchar(9)) + ')'

	If @internalMatchCode = 'PMT'
	Begin
		Set @sqlFrom = @sqlFrom + ' SOURCEJOBTABLE AS JobTable INNER JOIN'
		Set @sqlFrom = @sqlFrom + ' DATABASE..T_Peptides AS PT ON JobTable.Job = PT.Analysis_ID INNER JOIN'
		
		If @DB_Schema_Version >= 2 AND @internalMatchCode <> 'UMC'
			Set @sqlFrom = @sqlFrom + ' DATABASE..T_Score_Sequest AS SS ON PT.Peptide_ID = SS.Peptide_ID INNER JOIN'
		
		Set @sqlFrom = @sqlFrom + ' DATABASE..V_IFC_Mass_Tag_To_Protein_Map AS MTO INNER JOIN'
		Set @sqlFrom = @sqlFrom + ' DATABASE..T_Mass_Tags AS MT ON MTO.Mass_Tag_ID = MT.Mass_Tag_ID INNER JOIN'
		Set @sqlFrom = @sqlFrom + ' DATABASE..V_IFC_Proteins AS RefTable ON MTO.Ref_ID = RefTable.Ref_ID LEFT OUTER JOIN'
		Set @sqlFrom = @sqlFrom + ' DATABASE..T_Peptide_Cleavage_State_Name AS CSN ON MTO.Cleavage_State = CSN.Cleavage_State'
		Set @sqlFrom = @sqlFrom + ' ON PT.Mass_Tag_ID = MT.Mass_Tag_ID'
	End

	If @internalMatchCode = 'UMC'
	Begin
		Set @sqlFrom = @sqlFrom + ' DATABASE..T_FTICR_UMC_ResultDetails AS URD INNER JOIN'
		Set @sqlFrom = @sqlFrom + ' DATABASE..T_FTICR_UMC_Results AS FUR ON URD.UMC_Results_ID = FUR.UMC_Results_ID INNER JOIN'
		Set @sqlFrom = @sqlFrom + ' DATABASE..T_Match_Making_Description AS MMD ON FUR.MD_ID = MMD.MD_ID INNER JOIN'
		Set @sqlFrom = @sqlFrom + ' SOURCEJOBTABLE AS JobTable ON MMD.MD_Reference_Job = JobTable.Job INNER JOIN'
		Set @sqlFrom = @sqlFrom + ' DATABASE..T_Mass_Tags AS MT ON URD.Mass_Tag_ID = MT.Mass_Tag_ID INNER JOIN'
		Set @sqlFrom = @sqlFrom + ' DATABASE..V_IFC_Mass_Tag_To_Protein_Map AS MTO ON MT.Mass_Tag_ID = MTO.Mass_Tag_ID INNER JOIN'
		Set @sqlFrom = @sqlFrom + ' DATABASE..V_IFC_Proteins AS RefTable ON MTO.Ref_ID = RefTable.Ref_ID LEFT OUTER JOIN'
		Set @sqlFrom = @sqlFrom + ' DATABASE..T_Peptide_Cleavage_State_Name AS CSN ON MTO.Cleavage_State = CSN.Cleavage_State'

		Set @sqlWhere = @sqlWhere + ' AND (MMD.MD_Type = 1)'				-- Normal peak matching tasks only (not pairs)
		Set @sqlWhere = @sqlWhere + ' AND (URD.Match_State = 6)'			-- Rows marked as "Hits" only
		
		If @includeSupersededData = 'true'
			Set @sqlWhere = @sqlWhere + ' AND (MMD.MD_State IN (2, 5))'		-- Allow normal and superseded peak matching tasks
		Else
			Set @sqlWhere = @sqlWhere + ' AND (MMD.MD_State = 2)'			-- Normal peak matching tasks only
	End

	-- Add the Ad Hoc Where criteria, if applicable
	-- However, if the Ad Hoc criteria contains aggregation functions 
	-- like Count or Sum, then it must be added as a Having clause,
	-- which, admittedly, could give unexpected filtering results
	Set @sqlHaving = ''
	If Len(@criteriaSqlUpdated) > 0
	Begin
		If CharIndex('COUNT(', @criteriaSqlUpdated) > 0 OR CharIndex('SUM(', @criteriaSqlUpdated) > 0
			Set @sqlHaving = 'HAVING (' + @criteriaSqlUpdated + ')'
		Else
			Set @sqlWhere = @sqlWhere + ' AND (' + @criteriaSqlUpdated + ')'
	End
	
	-- Define the Order By clause
	Set @sqlOrderBy = 'ORDER BY JobTable.Experiment, RefTable.Reference, MT.Mass_Tag_ID'

	---------------------------------------------------
	-- Customize the database name and Job table name
	-- for the specific MTDB and match method
	---------------------------------------------------

	if @internalMatchCode = 'PMT'
	begin
		set @sqlFrom = replace(@sqlFrom, 'SOURCEJOBTABLE', @MTDBName + '..T_Analysis_Description')
		set @sqlFrom = replace(@sqlFrom, 'DATABASE..', '[' + @MTDBName + ']..')
	end

	if @internalMatchCode = 'UMC'
	begin
		set @sqlFrom = replace(@sqlFrom, 'SOURCEJOBTABLE', @MTDBName + '..T_FTICR_Analysis_Description')
		set @sqlFrom = replace(@sqlFrom, 'DATABASE..', '[' + @MTDBName + ']..')
	end

	---------------------------------------------------
	-- Parse @experiments and @Proteins to create a proper
	-- SQL where clause containing a mix of 
	-- Where xx In ('A','B') and Where xx Like ('C%') statements
	---------------------------------------------------

	Declare @experimentWhereClause varchar(8000),
			@ProteinWhereClause varchar(8000)
	Set @experimentWhereClause = ''
	Set @ProteinWhereClause = ''

	Exec ConvertListToWhereClause @experiments, 'JobTable.Experiment', @entryListWhereClause = @experimentWhereClause OUTPUT
	Exec ConvertListToWhereClause @Proteins, 'RefTable.Reference', @entryListWhereClause = @ProteinWhereClause OUTPUT

	---------------------------------------------------
	-- Obtain the mass tags from the given database
	---------------------------------------------------
	
	-- We could append @experimentWhereClause and @ProteinWhereClause to @sqlWhere, but the string length
	-- could become too long; thus, we'll add it in when we combine the Sql to Execute
	-- However, we need to prepend them with AND

	If Len(@experimentWhereClause) > 0
		Set @experimentWhereClause = ' AND (' + @experimentWhereClause + ')'

	If Len(@ProteinWhereClause) > 0
		Set @ProteinWhereClause = ' AND (' + @ProteinWhereClause + ')'
		
	-- DEBUG
	-- save dynamic query text
	--
	--INSERT INTO T_Junk(Contents) VALUES(@sqlSelect + ' ' + @sqlFrom + ' ' + @sqlWhere + @experimentWhereClause + @ProteinWhereClause + ' ' + @sqlGroupBy + ' ' + @sqlHaving + ' ' + @sqlOrderBy)	
		
	If @returnRowCount = 'true'
	begin
		-- In order to return the row count, we wrap the sql text with Count (*) 
		-- and exclude the @sqlOrderBy text from the sql statement
		Exec ('SELECT Count (*) As ResultSet_Row_Count FROM (' + @sqlSelect + ' ' + @sqlFrom + ' ' + @sqlWhere + @experimentWhereClause + @ProteinWhereClause + ' ' + @sqlGroupBy + ' ' + @sqlHaving + ') As LookupQ')
	end
	Else
	begin
		--Print  @sqlSelect + ' ' + @sqlFrom + ' ' + @sqlWhere + @experimentWhereClause + @ProteinWhereClause + ' ' + @sqlGroupBy + ' ' + @sqlHaving + ' ' + @sqlOrderBy
		Exec (@sqlSelect + ' ' + @sqlFrom + ' ' + @sqlWhere + @experimentWhereClause + @ProteinWhereClause + ' ' + @sqlGroupBy + ' ' + @sqlHaving + ' ' + @sqlOrderBy)
	end
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows; ' + @pepIdentMethod
	Exec PostUsageLogEntry 'GetMassTags', @MTDBName, @UsageMessage
	
Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[GetMassTags] TO [DMS_SP_User]
GO
