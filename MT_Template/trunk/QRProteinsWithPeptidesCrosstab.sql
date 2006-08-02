SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[QRProteinsWithPeptidesCrosstab]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[QRProteinsWithPeptidesCrosstab]
GO


CREATE Procedure dbo.QRProteinsWithPeptidesCrosstab
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
**  Auth: mem
**	Date: 08/05/2003
**
**	Updated: 08/15/2003
**			 08/19/2003
**			 08/26/2003
**           10/02/2003 mem - Changed Order By from Ref_ID to Reference
**			 11/13/2003 mem - Added Mass_Tag_Mods column
**			 11/14/2003 mem - Added Peptide column
**           12/13/2003 mem - Increased size of the @CrossTabSqlGroupBy variable
**			 04/09/2004 mem - Added ORF description to output (obtained from ORF DB defined in T_External_Databases)
**			 06/06/2004 mem - Now returning the Dynamic_Mod_List and/or Static_Mod_List columns if any of the peptides does not contain 'none' for the list value
**			 10/05/2004 mem - Updated for new MTDB schema
**			 10/26/2004 mem - Updated dynamic SQL to fix ambiguous column name bug
**			 05/24/2005 mem - Now returning "Internal_Std" in column Mass_Tag_Mods when Internal_Standard_Match = 1; and updated protein description linking method
**			 09/22/2005 mem - Now limiting the data returned when @SeparateReplicateDataIDs=1 to only include those proteins and peptides that would be seen if @SeparateReplicateDataIDs=0
**
****************************************************/
(
	@QuantitationIDList varchar(1024),					-- Comma separated list of Quantitation ID's
	@SeparateReplicateDataIDs tinyint = 1,				-- For quantitation ID's with replicates, separates the resultant crosstab table into a separate column for each replicate
	@SourceColName varchar(128) = 'MT_Abundance',		-- Column to return; valid columns include MT_Abundance, UMC_Match_Count, SingleMT_MassTagMatchingIonCount
	@AggregateColName varchar(128) = 'AvgAbu',
	@AverageAcrossColumns tinyint = 0					-- When = 1, then adds averages across columns, creating a more informative, but also more complex query
)
AS 

	Set NoCount On

	Declare @sql varchar(8000)

	Declare @CrossTabSql varchar(7000),			-- Note: This cannot be any larger than 7000 since we add it plus some other text to @sql
			@CrossTabSqlGroupBy varchar(8000),
			@QuantitationIDListSql varchar(1024),
			@OrfDescriptionSqlJoin varchar(1024),
			@ColumnListToShow varchar(900),
			@ERValuesPresent tinyint,
			@ModsPresent tinyint,
			@QuantitationIDListClean varchar(1024)

	Set @ERValuesPresent = 0
	Set @ModsPresent = 0
	Set @QuantitationIDListClean = ''
	
	--------------------------------------------------------------
	-- Call QRGenerateCrosstabSql to populate CrossTabSql and QuantitationIDListSql
	-- This SP also populates @ModsPresent and @StaticModsPresent
	--------------------------------------------------------------
	Exec QRGenerateCrosstabSql	@QuantitationIDList, 
								@SourceColName,
								@AggregateColName,
								@AverageAcrossColumns,				-- When @AverageAcrossColumns = 1, then set @NullWhenMissing = 1
								@SeparateReplicateDataIDs,
								@CrossTabSql = @CrossTabSql Output, 
								@CrossTabSqlGroupBy = @CrossTabSqlGroupBy Output,
								@QuantitationIDListSql = @QuantitationIDListSql Output,
								@ERValuesPresent = @ERValuesPresent Output,
								@ModsPresent = @ModsPresent Output,
								@QuantitationIDListClean = @QuantitationIDListClean output

	--------------------------------------------------------------
	-- Call QRGenerateORFDBJoinSql to populate @OrfDescriptionSqlJoin
	--------------------------------------------------------------
	Exec QRGenerateORFDBJoinSql @OrfDescriptionSqlJoin = @OrfDescriptionSqlJoin OUTPUT

	--------------------------------------------------------------
	-- Create dynamic SQL to generate resultset containing summary matrix
	--------------------------------------------------------------
	
	Set @sql = ''
	Set @sql = @sql + ' SELECT SubQ.Ref_ID,T_Proteins.Reference,'
	If Len(@OrfDescriptionSqlJoin) > 0
		Set @sql = @sql + ' ORFInfo.Protein_Description,'

	Set @sql = @sql + 'SubQ.Mass_Tag_ID,SubQ.Peptide,SubQ.Mass_Tag_Mods,'
	If @ModsPresent > 0
		Set @sql = @sql + 'SubQ.Mod_Description,'

	Set @sql = @sql + @CrossTabSql
	Set @sql = @sql + ' FROM ( SELECT QR.Quantitation_ID,QR.Ref_ID,QRD.Mass_Tag_ID,'
	Set @sql = @sql +               ' T_Mass_Tags.Peptide,T_Mass_Tags.Mod_Description,'
	Set @sql = @sql +               ' CASE WHEN QRD.Internal_Standard_Match = 1 THEN ''Internal_Std'' ELSE QRD.Mass_Tag_Mods END AS Mass_Tag_Mods,'
	Set @sql = @sql +               ' QRD.' + @SourceColName
	Set @sql = @sql +        ' FROM T_Quantitation_Results AS QR INNER JOIN'
    Set @sql = @sql +             ' T_Quantitation_ResultDetails AS QRD ON QR.QR_ID = QRD.QR_ID INNER JOIN'
    Set @sql = @sql +             ' T_Mass_Tags ON QRD.Mass_Tag_ID = T_Mass_Tags.Mass_Tag_ID'
	Set @sql = @sql +        ' WHERE QR.Quantitation_ID IN (' + @QuantitationIDListSql + ')'
	Set @sql = @sql +        ' ) AS SubQ'

	If @SeparateReplicateDataIDs <> 0 And Len(@QuantitationIDListClean) > 0
	Begin
		Set @sql = @sql +   ' INNER JOIN (SELECT DISTINCT QR2.Ref_ID AS RefID_Filter'
		Set @sql = @sql +             ' FROM T_Quantitation_Results AS QR2'
		Set @sql = @sql +             ' WHERE QR2.Quantitation_ID IN (' + @QuantitationIDListClean + ')'
		Set @sql = @sql +   ') As CompareQ ON SubQ.Ref_ID = CompareQ.RefID_Filter'
	End

	Set @sql = @sql + ' LEFT OUTER JOIN T_Proteins ON SubQ.Ref_ID = T_Proteins.Ref_ID'
	If Len(@OrfDescriptionSqlJoin) > 0
		Set @sql = @sql + @OrfDescriptionSqlJoin
		
	Set @sql = @sql + ' GROUP BY SubQ.Ref_ID,T_Proteins.Reference,SubQ.Mass_Tag_ID,SubQ.Peptide,SubQ.Mass_Tag_Mods'
	If @ModsPresent > 0
		Set @sql = @sql + ',SubQ.Mod_Description'

	If Len(@OrfDescriptionSqlJoin) > 0
		Set @sql = @sql + ', ORFInfo.Protein_Description'

	If @AverageAcrossColumns = 0
	  Begin
		Set @sql = @sql + ' ORDER BY T_Proteins.Reference,Mass_Tag_ID,Peptide,Mass_Tag_Mods'
		Exec (@sql)
	  End
	Else
	  Begin
		Set @ColumnListToShow = 'Ref_ID,Reference'
		If Len(@OrfDescriptionSqlJoin) > 0
		Begin
			Set @ColumnListToShow = @ColumnListToShow + ',Protein_Description'
		End
		Set @ColumnListToShow = @ColumnListToShow + ',Mass_Tag_ID,Peptide,Mass_Tag_Mods'
		If @ModsPresent > 0
			Set @ColumnListToShow = @ColumnListToShow + ',Mod_Description'
		
		-- Note: @CrossTabSqlGroupBy and @Sql could be quite long
		--       Thus, we'll concatenate during the Exec statement
		Exec ('SELECT ' + @ColumnListToShow + ',' + @CrossTabSqlGroupBy + ' FROM (' + @Sql + ') AS OuterQuery' + ' GROUP BY ' + @ColumnListToShow + ' ORDER BY Reference, Mass_Tag_ID, Peptide, Mass_Tag_Mods')
	  End

	Return @@Error


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[QRProteinsWithPeptidesCrosstab]  TO [DMS_SP_User]
GO

