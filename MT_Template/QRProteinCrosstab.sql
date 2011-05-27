/****** Object:  StoredProcedure [dbo].[QRProteinCrosstab] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure QRProteinCrosstab
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
**			06/04/2007 mem - Added parameter @PreviewSql and changed several string variables to varchar(max)
**			06/05/2007 mem - Updated to use the PIVOT operator (new to Sql Server 2005) to create the crosstab; added parameters @message and @PreviewSql; switched to Try/Catch error handling
**			06/13/2007 mem - Expanded the size of @QuantitationIDList to varchar(max)
**			01/24/2008 mem - Added column @DateStampHeaderColumn
**			10/22/2008 mem - Added parameter @ChangeCommasToSemicolons
**
****************************************************/
(
	@QuantitationIDList varchar(max),					-- Comma separated list of Quantitation ID's
	@SeparateReplicateDataIDs tinyint = 1,				-- For quantitation ID's with replicates, separates the resultant crosstab table into a separate column for each replicate
	@SourceColName varchar(128) = 'Abundance_Average',	-- Column to return; valid columns include Abundance_Average, MassTagCountUniqueObserved, MassTagCountUsedForAbundanceAvg, FractionScansMatchingSingleMassTag, ER, etc.
	@AggregateColName varchar(128) = 'AvgAbu',
	@AverageAcrossColumns tinyint = 0,					-- When = 1, then adds averages across columns, creating a more informative, but also more complex query
	@SortMode tinyint=0,								-- 0=Unsorted, 1=QID, 2=SampleName, 3=Comment, 4=Job (first job if more than one job), 5 = Dataset Acq_Time_Start
	@message varchar(512)='' output,
	@PreviewSql tinyint=0,
	@IncludeProteinDescription tinyint = 1,				-- Set to 1 to include protein descriptions; 0 to exclude them
	@DateStampHeaderColumn tinyint = 0,
	@MinimumPeptidesPerProtein tinyint = 0,				-- Set to 2 or higher to exclude proteins with MassTagCountUniqueObserved values less than this number
	@ChangeCommasToSemicolons tinyint = 0				-- Replaces commas with semicolons in various text fields, including: Reference and Protein Description
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
		-- Validate the inputs
		--------------------------------------------------------------
		Set @SeparateReplicateDataIDs  = IsNull(@SeparateReplicateDataIDs, 0)
		Set @SourceColName  = IsNull(@SourceColName, 'Abundance_Average')
		Set @AggregateColName  = IsNull(@AggregateColName, 'AvgAbu')
		Set @AverageAcrossColumns  = IsNull(@AverageAcrossColumns, 0)
		Set @SortMode  = IsNull(@SortMode, 0)
		set @message = ''
		Set @PreviewSql  = IsNull(@PreviewSql, 0)
		Set @IncludeProteinDescription = IsNull(@IncludeProteinDescription, 1)
		Set @DateStampHeaderColumn = IsNull(@DateStampHeaderColumn, 0)
		Set @MinimumPeptidesPerProtein  = IsNull(@MinimumPeptidesPerProtein, 0)
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
									@QuantitationIDListClean = @QuantitationIDListClean output,
									@DateStampHeaderColumn = @DateStampHeaderColumn


		--------------------------------------------------------------
		-- Create dynamic SQL to generate the pivot table
		--------------------------------------------------------------
		
		Set @CurrentLocation = 'Populate @Sql'
		
		Set @sql = ''
		Set @sql = @sql + ' SELECT PivotResults.Ref_ID,'
		
		If @ChangeCommasToSemicolons = 0
			Set @sql = @sql + 'Prot.Reference,'
		Else
			Set @sql = @sql + 'Replace(Prot.Reference, '','', '';'') AS Reference,'
		
		If @IncludeProteinDescription <> 0
		Begin
			If @ChangeCommasToSemicolons = 0
				Set @sql = @sql +         ' Prot.Description As Protein_Description,'
			Else
				Set @sql = @sql + ' Replace(Prot.Description, '','', '';'')  As Protein_Description,'
		End
			
			
		Set @sql = @sql +        @PivotColumnsSql
		Set @sql = @sql + ' FROM (SELECT QR.Quantitation_ID, QR.Ref_ID,'
		Set @sql = @sql +       ' CONVERT(VARCHAR(19), QR.' + @SourceColName + ') AS ' + @SourceColName
		Set @sql = @sql +       ' FROM  #TmpQIDSortInfo INNER JOIN '
		Set @sql = @sql +             ' T_Quantitation_Results QR ON #TmpQIDSortInfo.QID = QR.Quantitation_ID'
		If @MinimumPeptidesPerProtein > 0
			Set @sql = @sql +   ' WHERE QR.MassTagCountUniqueObserved >= ' + Convert(varchar(12), @MinimumPeptidesPerProtein)
		Set @sql = @sql +       ') AS DataQ'
		Set @sql = @sql +       ' PIVOT ('
		Set @sql = @sql +       '   MAX(' + @SourceColName + ') FOR Quantitation_ID IN ( ' + @QuantitationIDListSql + ' ) '
		Set @sql = @sql +       ' ) AS PivotResults'
		Set @sql = @sql +        ' LEFT OUTER JOIN T_Proteins Prot ON PivotResults.Ref_ID = Prot.Ref_ID'
		

		If @AverageAcrossColumns = 0
		Begin
			Set @sql = @sql + ' ORDER BY Prot.Reference'
		End
		Else
		Begin
			Set @ColumnListToShow = 'Ref_ID, Reference, Protein_Description '
			
			Set @Sql =        'SELECT ' + @ColumnListToShow + ',' + @CrossTabSqlGroupBy + ' FROM (' + @Sql + ') AS OuterQuery'
			Set @Sql = @Sql + ' GROUP BY ' + @ColumnListToShow + ' ORDER BY ' + @AggregateColName + ' DESC, Reference'
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
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'QRProteinCrosstab')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch

Done:
	Return @myError

GO
GRANT EXECUTE ON [dbo].[QRProteinCrosstab] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QRProteinCrosstab] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QRProteinCrosstab] TO [MTS_DB_Lite] AS [dbo]
GO
