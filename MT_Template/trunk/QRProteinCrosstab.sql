/****** Object:  StoredProcedure [dbo].[QRProteinCrosstab] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
**  Auth:	mem
**	Date:	07/30/2003
**			08/08/2003
**			08/14/2003
**			08/15/2003
**			08/19/2003
**          12/13/2003 mem - Increased size of the @CrossTabSqlGroupBy variable
**			04/09/2004 mem - Added ORF description to output (obtained from ORF DB defined in T_External_Databases)
**			10/05/2004 mem - Updated for new MTDB schema
**			05/24/2005 mem - Updated protein description linking method
**			09/22/2005 mem - Now limiting the data returned when @SeparateReplicateDataIDs=1 to only include those proteins that would be seen if @SeparateReplicateDataIDs=0
**			07/25/2006 mem - Now obtaining the protein Description from T_Proteins instead of from an external ORF database
**			11/28/2006 mem - Added parameter @SortMode, which affects the order in which the results are returned
**
****************************************************/
(
	@QuantitationIDList varchar(1024),					-- Comma separated list of Quantitation ID's
	@SeparateReplicateDataIDs tinyint = 1,				-- For quantitation ID's with replicates, separates the resultant crosstab table into a separate column for each replicate
	@SourceColName varchar(128) = 'Abundance_Average',	-- Column to return; valid columns include Abundance_Average, MassTagCountUniqueObserved, MassTagCountUsedForAbundanceAvg, FractionScansMatchingSingleMassTag, etc.
	@AggregateColName varchar(128) = 'AvgAbu',
	@AverageAcrossColumns tinyint = 0,					-- When = 1, then adds averages across columns, creating a more informative, but also more complex query
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
			@ColumnListToShow varchar(700),
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
	
	Set @sql = ''
	Set @sql = @sql + ' SELECT SubQ.Ref_ID,T_Proteins.Reference,'
	Set @sql = @sql + ' T_Proteins.Description As Protein_Description,'
	Set @sql = @sql + @CrossTabSql
	Set @sql = @sql + ' FROM (SELECT QR.Quantitation_ID, QR.Ref_ID, QR.' + @SourceColName
	Set @sql = @sql +       ' FROM  #TmpQIDSortInfo INNER JOIN '
	Set @sql = @sql +             ' T_Quantitation_Results QR ON #TmpQIDSortInfo.QID = QR.Quantitation_ID'
	Set @sql = @sql +       ') AS SubQ'

	If @SeparateReplicateDataIDs <> 0 And Len(@QuantitationIDListClean) > 0
	Begin
		Set @sql = @sql +   ' INNER JOIN (SELECT DISTINCT QR2.Ref_ID AS RefID_Filter'
		Set @sql = @sql +             ' FROM T_Quantitation_Results AS QR2'
		Set @sql = @sql +             ' WHERE QR2.Quantitation_ID IN (' + @QuantitationIDListClean + ')'
		Set @sql = @sql +   ') As CompareQ ON SubQ.Ref_ID = CompareQ.RefID_Filter'
	End

	Set @sql = @sql +       ' LEFT OUTER JOIN T_Proteins ON SubQ.Ref_ID = T_Proteins.Ref_ID'
	Set @sql = @sql + ' GROUP BY SubQ.Ref_ID, T_Proteins.Reference, T_Proteins.Description'

	If @AverageAcrossColumns = 0
	Begin
		Set @sql = @sql + ' ORDER BY T_Proteins.Reference'
		Exec (@sql)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End
	Else
	Begin
		Set @ColumnListToShow = 'Ref_ID, Reference, Protein_Description '
		
		-- Note: @CrossTabSqlGroupBy and @Sql could be quite long
		--       Thus, we'll concatenate during the Exec statement
		Exec ('SELECT ' + @ColumnListToShow + ',' + @CrossTabSqlGroupBy + ' FROM (' + @Sql + ') AS OuterQuery' + ' GROUP BY ' + @ColumnListToShow + ' ORDER BY ' + @AggregateColName + ' DESC, Reference')
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End

Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[QRProteinCrosstab] TO [DMS_SP_User]
GO
