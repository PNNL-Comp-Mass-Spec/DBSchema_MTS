SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[QRProteinCrosstab]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[QRProteinCrosstab]
GO


CREATE Procedure dbo.QRProteinCrosstab 
/****************************************************	
**  Desc: Generates a cross tab query of the proteins observed
**		  in 1 or more QuantitationID tasks
**
**  Return values: 0 if success, otherwise, error code
**
**  Parameters: QuantitationID List to process
**
**  Auth: mem
**	Date: 07/30/2003
**
**	Updated: 08/08/2003
**			 08/14/2003
**			 08/15/2003
**			 08/19/2003
**           12/13/2003 mem - Increased size of the @CrossTabSqlGroupBy variable
**			 04/09/2004 mem - Added ORF description to output (obtained from ORF DB defined in T_External_Databases)
**			 10/05/2004 mem - Updated for new MTDB schema
**			 05/24/2005 mem - Updated protein description linking method
**			 09/22/2005 mem - Now limiting the data returned when @SeparateReplicateDataIDs=1 to only include those proteins that would be seen if @SeparateReplicateDataIDs=0
**
****************************************************/
(
	@QuantitationIDList varchar(1024),					-- Comma separated list of Quantitation ID's
	@SeparateReplicateDataIDs tinyint = 1,				-- For quantitation ID's with replicates, separates the resultant crosstab table into a separate column for each replicate
	@SourceColName varchar(128) = 'Abundance_Average',	-- Column to return; valid columns include Abundance_Average, MassTagCountUniqueObserved, MassTagCountUsedForAbundanceAvg, FractionScansMatchingSingleMassTag, etc.
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
			@ColumnListToShow varchar(700),
			@ERValuesPresent tinyint,
			@ModsPresent tinyint,
			@QuantitationIDListClean varchar(1024)

	Set @ERValuesPresent = 0
	Set @ModsPresent = 0
	Set @QuantitationIDListClean = ''

	--------------------------------------------------------------
	-- Call QRGenerateCrosstabSql to populate CrossTabSql and QuantitationIDListSql
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
	Set @sql = @sql + @CrossTabSql
	Set @sql = @sql + ' FROM (SELECT Quantitation_ID, Ref_ID, ' + @SourceColName
	Set @sql = @sql +       ' FROM   T_Quantitation_Results '
	Set @sql = @sql +       ' WHERE  Quantitation_ID IN (' + @QuantitationIDListSql + ')'
	Set @sql = @sql +       ') AS SubQ'

	If @SeparateReplicateDataIDs <> 0 And Len(@QuantitationIDListClean) > 0
	Begin
		Set @sql = @sql +   ' INNER JOIN (SELECT DISTINCT QR2.Ref_ID AS RefID_Filter'
		Set @sql = @sql +             ' FROM T_Quantitation_Results AS QR2'
		Set @sql = @sql +             ' WHERE QR2.Quantitation_ID IN (' + @QuantitationIDListClean + ')'
		Set @sql = @sql +   ') As CompareQ ON SubQ.Ref_ID = CompareQ.RefID_Filter'
	End

	Set @sql = @sql +       ' LEFT OUTER JOIN T_Proteins ON SubQ.Ref_ID = T_Proteins.Ref_ID'
	If Len(@OrfDescriptionSqlJoin) > 0
		Set @sql = @sql + @OrfDescriptionSqlJoin
	Set @sql = @sql + ' GROUP BY SubQ.Ref_ID, T_Proteins.Reference'
	If Len(@OrfDescriptionSqlJoin) > 0
		Set @sql = @sql + ', ORFInfo.Protein_Description'

	If @AverageAcrossColumns = 0
	  Begin
		Set @sql = @sql + ' ORDER BY T_Proteins.Reference'
		Exec (@sql)
	  End
	Else
	  Begin
		Set @ColumnListToShow = 'Ref_ID, Reference '
		If Len(@OrfDescriptionSqlJoin) > 0
		Begin
			Set @ColumnListToShow = @ColumnListToShow + ',Protein_Description '
		End
		
		-- Note: @CrossTabSqlGroupBy and @Sql could be quite long
		--       Thus, we'll concatenate during the Exec statement
		Exec ('SELECT ' + @ColumnListToShow + ',' + @CrossTabSqlGroupBy + ' FROM (' + @Sql + ') AS OuterQuery' + ' GROUP BY ' + @ColumnListToShow + ' ORDER BY ' + @AggregateColName + ' DESC, Reference')
	  End

	Return @@Error


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[QRProteinCrosstab]  TO [DMS_SP_User]
GO

