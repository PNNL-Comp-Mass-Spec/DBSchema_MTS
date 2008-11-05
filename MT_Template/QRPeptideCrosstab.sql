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
**			06/04/2007 mem - Added parameter @PreviewSql and changed several string variables to varchar(max)
**			06/05/2007 mem - Updated to use the PIVOT operator (new to Sql Server 2005) to create the crosstab; added parameters @message and @PreviewSql; switched to Try/Catch error handling
**
****************************************************/
(
	@QuantitationIDList varchar(max),					-- Comma separated list of Quantitation ID's
	@SeparateReplicateDataIDs tinyint = 1,				-- For quantitation ID's with replicates, separates the resultant crosstab table into a separate column for each replicate
	@SourceColName varchar(128) = 'MT_Abundance',		-- Column to return; valid columns include MT_Abundance, UMC_Match_Count, SingleMT_MassTagMatchingIonCount
	@AggregateColName varchar(128) = 'AvgAbu',
	@AverageAcrossColumns tinyint = 0,					-- When = 1, then adds averages across columns, creating a more informative, but also more complex query
	@IncludePrefixAndSuffixResidues tinyint = 0,		-- The query is slower if this is enabled
	@SortMode tinyint=0,								-- 0=Unsorted, 1=QID, 2=SampleName, 3=Comment, 4=Job (first job if more than one job)
	@message varchar(512)='' output,
	@PreviewSql tinyint=0
)
AS

	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	Declare @sql varchar(max)

	Declare @PivotColumnsSql varchar(max),
			@QuantitationIDListSql varchar(max),
			@CrossTabSqlGroupBy varchar(max),
			@ColumnListToShow varchar(900),
			@ColumnListToShow2 varchar(900),
			@ERValuesPresent tinyint,
			@ModsPresent tinyint,
			@QuantitationIDListClean varchar(max)

	Set @ERValuesPresent = 0
	Set @ModsPresent = 0
	Set @QuantitationIDListClean = ''

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		
		--------------------------------------------------------------
		-- Create a temporary table to hold the QIDs and sorting info
		-- This table is populated by QRGenerateCrosstabSql
		--------------------------------------------------------------
				
		CREATE TABLE #TmpQIDSortInfo (
			SortKey int identity (1,1),
			QID int NOT NULL)

		--------------------------------------------------------------
		-- Call QRGenerateCrosstabSql to populate @PivotColumnsSql and @QuantitationIDListSql
		-- This SP also populates @ModsPresent
		--------------------------------------------------------------
		
		Set @CurrentLocation = 'Call QRGenerateCrosstabSql'
		--
		Exec QRGenerateCrosstabSql	@QuantitationIDList, 
									@SourceColName,
									@AggregateColName,
									@AverageAcrossColumns,				-- When @AverageAcrossColumns = 1, then set @NullWhenMissing = 1
									@SeparateReplicateDataIDs,
									@SortMode,
									@SkipCrossTabSqlGeneration = 0,
									@PivotColumnsSql = @PivotColumnsSql output,
									@CrossTabSqlGroupBy = @CrossTabSqlGroupBy output,
									@QuantitationIDListSql = @QuantitationIDListSql output,
									@ERValuesPresent = @ERValuesPresent output,
									@ModsPresent = @ModsPresent output,
									@QuantitationIDListClean = @QuantitationIDListClean output

		
		--------------------------------------------------------------
		-- Create dynamic SQL to generate the pivot table
		--------------------------------------------------------------
		
		Set @CurrentLocation = 'Populate @Sql'
		
		Set @ColumnListToShow = 'MT.Mass_Tag_ID,'
		
		If @IncludePrefixAndSuffixResidues <> 0
			Set @ColumnListToShow = @ColumnListToShow + 'MIN(MTPM.Peptide_Sequence) AS Peptide,'
		Else
			Set @ColumnListToShow = @ColumnListToShow + 'MT.Peptide,'
			
		Set @ColumnListToShow = @ColumnListToShow + 'PivotResults.Mass_Tag_Mods'
		Set @ColumnListToShow2 = 'Mass_Tag_ID, Peptide, Mass_Tag_Mods'
		
		If @ModsPresent > 0
		Begin
			Set @ColumnListToShow = @ColumnListToShow + ',MT.Mod_Description'
			Set @ColumnListToShow2 = @ColumnListToShow2 + ',Mod_Description'
		End
		
		Set @sql = ''
		Set @sql = @sql + ' SELECT ' + @ColumnListToShow + ', '
		Set @sql = @sql +          @PivotColumnsSql

		Set @sql = @sql + ' FROM  (SELECT QR.Quantitation_ID, QRD.Mass_Tag_ID,'
		If @IncludePrefixAndSuffixResidues <> 0
			Set @sql = @sql + ' QR.Ref_ID,'

		Set @sql = @sql +         ' CASE WHEN QRD.Internal_Standard_Match = 1 THEN ''Internal_Std'' ELSE QRD.Mass_Tag_Mods END AS Mass_Tag_Mods,'
		Set @sql = @sql +         ' CONVERT(VARCHAR(19), QRD.' + @SourceColName + ') AS ' + @SourceColName
		Set @sql = @sql +       ' FROM #TmpQIDSortInfo INNER JOIN '
		Set @sql = @sql +            ' T_Quantitation_Results QR ON #TmpQIDSortInfo.QID = QR.Quantitation_ID INNER JOIN'
		Set @sql = @sql +            ' T_Quantitation_ResultDetails QRD ON QR.QR_ID = QRD.QR_ID) AS DataQ'
		Set @sql = @sql +       ' PIVOT ('
		Set @sql = @sql +       '   MAX(' + @SourceColName + ') FOR Quantitation_ID IN ( ' + @QuantitationIDListSql + ' ) '
		Set @sql = @sql +       ' ) AS PivotResults'
		Set @sql = @sql +        ' INNER JOIN T_Mass_Tags MT ON PivotResults.Mass_Tag_ID = MT.Mass_Tag_ID'

		If @IncludePrefixAndSuffixResidues <> 0
		Begin
			Set @sql = @sql +    ' INNER JOIN V_Mass_Tag_to_Protein_Map_Full_Sequence MTPM ON'
			Set @sql = @sql +       ' MT.Mass_Tag_ID = MTPM.Mass_Tag_ID AND PivotResults.Ref_ID = MTPM.Ref_ID'

			Set @sql = @sql +   ' GROUP BY MT.Mass_Tag_ID, MT.Peptide, PivotResults.Mass_Tag_Mods, MT.Mod_Description,' + @QuantitationIDListSql
		End
		
		
		If @AverageAcrossColumns = 0
		Begin
			Set @sql = @sql + ' ORDER BY MT.Mass_Tag_ID, MT.Peptide, PivotResults.Mass_Tag_Mods'
		End
		Else
		Begin
			Set @Sql =        ' SELECT ' + @ColumnListToShow2 + ',' + @CrossTabSqlGroupBy + ' FROM (' + @Sql + ') AS OuterQuery'
			Set @Sql = @Sql + ' GROUP BY ' + @ColumnListToShow2 + ' ORDER BY ' + @AggregateColName + ' DESC, Mass_Tag_ID'
		End

		Set @CurrentLocation = 'Execute @Sql'
		--
		If @PreviewSql <> 0
			Print @Sql
		Else
			Exec (@Sql)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'QRPeptideCrosstab')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch

Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[QRPeptideCrosstab] TO [DMS_SP_User]
GO
GRANT VIEW DEFINITION ON [dbo].[QRPeptideCrosstab] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[QRPeptideCrosstab] TO [MTS_DB_Lite]
GO
