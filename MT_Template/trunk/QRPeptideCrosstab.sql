/****** Object:  StoredProcedure [dbo].[QRPeptideCrosstab] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.QRPeptideCrosstab
/****************************************************	
**  Desc: Generates a cross tab query of the peptides observed
**		  in 1 or more QuantitationID tasks
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: QuantitationID List to process
**
**  Auth:	mem
**	Date:	07/30/2003
**			08/14/2003
**			08/15/2003
**			08/19/2003
**			08/26/2003
**			11/13/2003 mem - Added Mass_Tag_Mods column
**			11/14/2003 mem - Added Peptide column
**          12/13/2003 mem - Increased size of the @CrossTabSqlGroupBy variable
**			06/06/2004 mem - Now returning the Dynamic_Mod_List and/or Static_Mod_List columns if any of the peptides does not contain 'none' for the list value
**			10/05/2004 mem - Updated for new MTDB schema
**			10/26/2004 mem - Updated dynamic SQL to fix ambiguous column name bug
**			05/24/2005 mem - Now returning "Internal_Std" in column Mass_Tag_Mods when Internal_Standard_Match = 1; and updated protein description linking method
**			09/22/2005 mem - Now limiting the data returned when @SeparateReplicateDataIDs=1 to only include those peptides that would be seen if @SeparateReplicateDataIDs=0
**			01/30/2006 mem - Added parameter @IncludePrefixAndSuffixResidues, which, when enabled, will cause the peptide sequence displayed to have prefix and suffix residues
**			11/28/2006 mem - Added parameter @SortMode, which affects the order in which the results are returned
**
****************************************************/
(
	@QuantitationIDList varchar(1024),					-- Comma separated list of Quantitation ID's
	@SeparateReplicateDataIDs tinyint = 1,				-- For quantitation ID's with replicates, separates the resultant crosstab table into a separate column for each replicate
	@SourceColName varchar(128) = 'MT_Abundance',		-- Column to return; valid columns include MT_Abundance, UMC_Match_Count, SingleMT_MassTagMatchingIonCount
	@AggregateColName varchar(128) = 'AvgAbu',
	@AverageAcrossColumns tinyint = 0,					-- When = 1, then adds averages across columns, creating a more informative, but also more complex query
	@IncludePrefixAndSuffixResidues tinyint = 0,			-- The query is slower if this is enabled
	@SortMode tinyint=0									-- 0=Unsorted, 1=QID, 2=SampleName, 3=Comment, 4=Job (first job if more than one job)
)
AS

	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	Declare @sql varchar(8000)

	Declare @CrossTabSql varchar(7000),			-- Note: This cannot be any larger than 7000 since we add it plus some other text to @sql
			@CrossTabSqlGroupBy varchar(8000),
			@ColumnListToShow varchar(900),
			@ERValuesPresent tinyint,
			@ModsPresent tinyint,
			@QuantitationIDListClean varchar(1024)

	Set @ERValuesPresent = 0
	Set @ModsPresent = 0
	Set @QuantitationIDListClean = ''
	
	--------------------------------------------------------------
	-- Create a temporary table to hold the QIDs and sorting info
	--------------------------------------------------------------
			
	CREATE TABLE #TmpQIDSortInfo (
		SortKey int identity (1,1),
		QID int NOT NULL)

	--------------------------------------------------------------
	-- Call QRGenerateCrosstabSql to populate CrossTabSql and QuantitationIDListSql
	-- This SP also populates @ModsPresent
	--------------------------------------------------------------
	Exec QRGenerateCrosstabSql	@QuantitationIDList, 
								@SourceColName,
								@AggregateColName,
								@AverageAcrossColumns,				-- When @AverageAcrossColumns = 1, then set @NullWhenMissing = 1
								@SeparateReplicateDataIDs,
								@SortMode,
								@SkipCrossTabSqlGeneration = 0,
								@CrossTabSql = @CrossTabSql Output, 
								@CrossTabSqlGroupBy = @CrossTabSqlGroupBy Output,
								@ERValuesPresent = @ERValuesPresent Output,
								@ModsPresent = @ModsPresent Output,
								@QuantitationIDListClean = @QuantitationIDListClean output

	
	--------------------------------------------------------------
	-- Create dynamic SQL to generate resultset containing summary matrix
	--------------------------------------------------------------
	
	Set @ColumnListToShow = ''
	Set @ColumnListToShow = @ColumnListToShow + 'Mass_Tag_ID, Peptide, Mass_Tag_Mods'
	If @ModsPresent > 0
		Set @ColumnListToShow = @ColumnListToShow + ',Mod_Description'
	
	Set @sql = ''
	Set @sql = @sql + ' SELECT ' + @ColumnListToShow + ', '
	Set @sql = @sql + @CrossTabSql
	Set @sql = @sql + ' FROM (SELECT QR.Quantitation_ID, QRD.Mass_Tag_ID,'
	If @IncludePrefixAndSuffixResidues <> 0
		Set @sql = @sql + ' MIN(MTPM.Peptide_Sequence) AS Peptide,'
	Else
		Set @sql = @sql + ' MT.Peptide,'

	Set @sql = @sql +              ' MT.Mod_Description,'
	Set @sql = @sql +              ' CASE WHEN QRD.Internal_Standard_Match = 1 THEN ''Internal_Std'' ELSE QRD.Mass_Tag_Mods END AS Mass_Tag_Mods,'
	Set @sql = @sql +              ' QRD.' + @SourceColName
	Set @sql = @sql +       ' FROM #TmpQIDSortInfo INNER JOIN '
	Set @sql = @sql +            ' T_Quantitation_Results QR ON #TmpQIDSortInfo.QID = QR.Quantitation_ID INNER JOIN'
	Set @sql = @sql +            ' T_Quantitation_ResultDetails QRD ON QR.QR_ID = QRD.QR_ID INNER JOIN'
    Set @sql = @sql +            ' T_Mass_Tags MT ON QRD.Mass_Tag_ID = MT.Mass_Tag_ID'
    If @IncludePrefixAndSuffixResidues <> 0
	Begin
		Set @sql = @sql +        ' INNER JOIN V_Mass_Tag_to_Protein_Map_Full_Sequence MTPM ON'
		Set @sql = @sql +        ' MT.Mass_Tag_ID = MTPM.Mass_Tag_ID AND QR.Ref_ID = MTPM.Ref_ID'
	End

    If @IncludePrefixAndSuffixResidues <> 0
	Begin
		Set @sql = @sql +   ' GROUP BY QR.Quantitation_ID, QRD.Mass_Tag_ID, MT.Mod_Description, CASE WHEN QRD.Internal_Standard_Match = 1 THEN ''Internal_Std'' ELSE QRD.Mass_Tag_Mods END, QRD.' + @SourceColName
	End
	
	Set @sql = @sql +       ') AS SubQ'
	
	If @SeparateReplicateDataIDs <> 0 And Len(@QuantitationIDListClean) > 0
	Begin
		Set @sql = @sql +   ' INNER JOIN (SELECT DISTINCT QRD2.Mass_Tag_ID AS MTID_Filter'
		Set @sql = @sql +             ' FROM T_Quantitation_Results AS QR2 INNER JOIN'
		Set @sql = @sql +                  ' T_Quantitation_ResultDetails AS QRD2 ON QR2.QR_ID = QRD2.QR_ID'
		Set @sql = @sql +             ' WHERE QR2.Quantitation_ID IN (' + @QuantitationIDListClean + ')'
		Set @sql = @sql +   ') As CompareQ ON SubQ.Mass_Tag_ID = CompareQ.MTID_Filter'
	End
	
	Set @sql = @sql + '	GROUP BY ' + @ColumnListToShow
	
	If @AverageAcrossColumns = 0
	Begin
		Set @sql = @sql + ' ORDER BY SubQ.Mass_Tag_ID, Peptide, Mass_Tag_Mods'
		Exec (@sql)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End
	Else
	Begin
		-- Note: @CrossTabSqlGroupBy and @Sql could be quite long
		--       Thus, we'll concatenate during the Exec statement
		Exec ('SELECT ' + @ColumnListToShow + ',' + @CrossTabSqlGroupBy + ' FROM (' + @Sql + ') AS OuterQuery' + ' GROUP BY ' + @ColumnListToShow + ' ORDER BY ' + @AggregateColName + ' DESC, Mass_Tag_ID, Peptide, Mass_Tag_Mods')
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End

Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[QRPeptideCrosstab] TO [DMS_SP_User]
GO
