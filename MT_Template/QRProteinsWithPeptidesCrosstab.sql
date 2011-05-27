/****** Object:  StoredProcedure [dbo].[QRProteinsWithPeptidesCrosstab] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure QRProteinsWithPeptidesCrosstab
/****************************************************	
**  Desc: Returns the proteins and peptides for the
**		  given list of QuantitationID's, sorted by
**		  protein, and then by peptide, listing peptide
**        abundances; this is a Crosstab-type query in that 
**        blanks are included if the peptide was not seen
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: QuantitationID List to process
**
**  Auth:	mem
**	Date:	08/05/2003
**			08/15/2003
**			08/19/2003
**			08/26/2003
**          10/02/2003 mem - Changed Order By from Ref_ID to Reference
**			11/13/2003 mem - Added Mass_Tag_Mods column
**			11/14/2003 mem - Added Peptide column
**          12/13/2003 mem - Increased size of the @CrossTabSqlGroupBy variable
**			04/09/2004 mem - Added ORF description to output (obtained from ORF DB defined in T_External_Databases)
**			06/06/2004 mem - Now returning the Dynamic_Mod_List and/or Static_Mod_List columns if any of the peptides does not contain 'none' for the list value
**			10/05/2004 mem - Updated for new MTDB schema
**			10/26/2004 mem - Updated dynamic SQL to fix ambiguous column name bug
**			05/24/2005 mem - Now returning "Internal_Std" in column Mass_Tag_Mods when Internal_Standard_Match = 1; and updated protein description linking method
**			09/22/2005 mem - Now limiting the data returned when @SeparateReplicateDataIDs=1 to only include those proteins and peptides that would be seen if @SeparateReplicateDataIDs=0
**			01/30/2006 mem - Added parameter @IncludePrefixAndSuffixResidues, which, when enabled, will cause the peptide sequence displayed to have prefix and suffix residues
**			07/25/2006 mem - Now obtaining the protein Description from T_Proteins instead of from an external ORF database
**			11/28/2006 mem - Added parameter @SortMode, which affects the order in which the results are returned
**			06/04/2007 mem - Added parameter @PreviewSql and changed several string variables to varchar(max)
**			06/05/2007 mem - Updated to use the PIVOT operator (new to Sql Server 2005) to create the crosstab; added parameters @message and @PreviewSql; switched to Try/Catch error handling
**			06/13/2007 mem - Expanded the size of @QuantitationIDList to varchar(max)
**			10/22/2008 mem - Added parameter @ChangeCommasToSemicolons
**
****************************************************/
(
	@QuantitationIDList varchar(max),					-- Comma separated list of Quantitation ID's
	@SeparateReplicateDataIDs tinyint = 1,				-- For quantitation ID's with replicates, separates the resultant crosstab table into a separate column for each replicate
	@SourceColName varchar(128) = 'MT_Abundance',		-- Column to return; valid columns include MT_Abundance, UMC_Match_Count, SingleMT_MassTagMatchingIonCount, and ER
	@AggregateColName varchar(128) = 'AvgAbu',
	@AverageAcrossColumns tinyint = 0,					-- When = 1, then adds averages across columns, creating a more informative, but also more complex query
	@IncludePrefixAndSuffixResidues tinyint = 0,		-- The query is slower if this is enabled
	@SortMode tinyint=0,								-- 0=Unsorted, 1=QID, 2=SampleName, 3=Comment, 4=Job (first job if more than one job)
	@message varchar(512)='' output,
	@PreviewSql tinyint=0,
	@ChangeCommasToSemicolons tinyint = 0				-- Replaces commas with semicolons in various text fields, including: Protein Description and Mod_Description

)
AS 

	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	Declare @Sql varchar(max)

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
		-- Validate the inputs
		--------------------------------------------------------------
		
		Set @SeparateReplicateDataIDs = IsNull(@SeparateReplicateDataIDs, 1)
		Set @SourceColName = IsNull(@SourceColName, 'MT_Abundance')
		Set @AggregateColName = IsNull(@AggregateColName, 'AvgAbu')
		Set @AverageAcrossColumns = IsNull(@AverageAcrossColumns, 0)
		Set @IncludePrefixAndSuffixResidues = IsNull(@IncludePrefixAndSuffixResidues, 0)
		Set @SortMode = IsNull(@SortMode, 0)
		Set @message =  ''
		Set @PreviewSql = IsNull(@PreviewSql, 0)
		Set @ChangeCommasToSemicolons = IsNull(@ChangeCommasToSemicolons, 0)
	
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

		Set @ColumnListToShow = ''
		Set @ColumnListToShow = @ColumnListToShow + 'PivotResults.Ref_ID,'
		
		If @ChangeCommasToSemicolons = 0
			Set @ColumnListToShow = @ColumnListToShow + 'Prot.Reference,'
		Else
			Set @ColumnListToShow = @ColumnListToShow + 'Replace(Prot.Reference, '','', '';'') AS Reference,'
		
		If @ChangeCommasToSemicolons = 0
			Set @ColumnListToShow = @ColumnListToShow + 'Prot.Description As Protein_Description,'
		Else
			Set @ColumnListToShow = @ColumnListToShow + 'Replace(Prot.Description, '','', '';'') As Protein_Description,'

		Set @ColumnListToShow = @ColumnListToShow + 'MT.Mass_Tag_ID,'
		
		If @IncludePrefixAndSuffixResidues <> 0
			Set @ColumnListToShow = @ColumnListToShow + 'MIN(MTPM.Peptide_Sequence) AS Peptide,'
		Else
			Set @ColumnListToShow = @ColumnListToShow + 'MT.Peptide,'
		
		Set @ColumnListToShow = @ColumnListToShow + 'PivotResults.Mass_Tag_Mods'
		Set @ColumnListToShow2 = 'Ref_ID, Reference, Protein_Description, Mass_Tag_ID, Peptide, Mass_Tag_Mods'
		
		If @ModsPresent > 0
		Begin
			If @ChangeCommasToSemicolons = 0
				Set @ColumnListToShow = @ColumnListToShow + ',MT.Mod_Description'
			Else
				Set @ColumnListToShow = @ColumnListToShow + ', Replace(MT.Mod_Description, '','', '';'') AS Mod_Description'
			
			Set @ColumnListToShow2 = @ColumnListToShow2 + ',Mod_Description'
		End

		Set @sql = ''
		Set @sql = @sql + ' SELECT ' + @ColumnListToShow + ', '
		Set @sql = @sql +          @PivotColumnsSql

		Set @sql = @sql + ' FROM  (SELECT QR.Quantitation_ID, QR.Ref_ID, QRD.Mass_Tag_ID,'
		Set @sql = @sql +    ' CASE WHEN QRD.Internal_Standard_Match = 1 THEN ''Internal_Std'' ELSE QRD.Mass_Tag_Mods END AS Mass_Tag_Mods,'
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
		End
		Set @sql = @sql +        ' LEFT OUTER JOIN T_Proteins Prot ON PivotResults.Ref_ID = Prot.Ref_ID'
		
		If @IncludePrefixAndSuffixResidues <> 0
		Begin
			Set @sql = @sql +   ' GROUP BY PivotResults.Ref_ID, Prot.Reference, Prot.Description, MT.Mass_Tag_ID, MT.Peptide, PivotResults.Mass_Tag_Mods, MT.Mod_Description,' + @QuantitationIDListSql
		End
		

		If @AverageAcrossColumns = 0
		Begin
			Set @Sql = @Sql + ' ORDER BY Prot.Reference, MT.Mass_Tag_ID, MT.Peptide, PivotResults.Mass_Tag_Mods'
		End
		Else
		Begin
			Set @Sql =        ' SELECT ' + @ColumnListToShow2 + ',' + @CrossTabSqlGroupBy + ' FROM (' + @Sql + ') AS OuterQuery' 
			Set @Sql = @Sql + ' GROUP BY ' + @ColumnListToShow2 + ' ORDER BY Reference, Mass_Tag_ID, Peptide, Mass_Tag_Mods'
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
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'QRProteinsWithPeptidesCrosstab')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch

Done:
	Return @myError

GO
GRANT EXECUTE ON [dbo].[QRProteinsWithPeptidesCrosstab] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QRProteinsWithPeptidesCrosstab] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QRProteinsWithPeptidesCrosstab] TO [MTS_DB_Lite] AS [dbo]
GO
