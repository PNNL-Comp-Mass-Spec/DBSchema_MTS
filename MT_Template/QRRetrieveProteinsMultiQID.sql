/****** Object:  StoredProcedure [dbo].[QRRetrieveProteinsMultiQID] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Procedure QRRetrieveProteinsMultiQID
/****************************************************	
**  Desc: Returns the proteins and associated statistics
**		    for the given list of QuantitationID's
**        This information is identical to that returned by QRRetrieveProteins,
**          except that this SP can handle multiple quantitation ID's
**          and returns the information in one large table
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: QuantitationID List to process
**
**  Auth:	mem
**	Date:	11/14/2003
**
**			11/18/2003 mem - Updated @ERValuesPresent test to use MAX(ABS(ER_Average)) rather than simply MAX(ER_Average)
**			12/01/2003 mem - Fixed bug in link to ExtendedStatsLookup table to Join on Quantitation_ID in addition to Ref_ID
**			04/09/2004 mem - Added ORF description to output (obtained from ORF DB defined in T_External_Databases)
**						   - Added Average ORF Count for each protein (based on MT.Multiple_ORF+1 for each peptide)
**						   - Removed ExtendedStatsLookup code since values are now stored in T_Quantitation_Results
**						   - Added 11 new output columns:
**							  Mass_Error_PPM_Avg, ORF_Count_Avg, 
**							  Full_Enzyme_Count, Potential_Full_Enzyme_Count, 
**							  Full_Enzyme_No_Missed_Cleavage_Count, 
**							  Partial_Enzyme_Count, Potential_Partial_Enzyme_Count, 
**							  ORF_Coverage_Residue_Count, Potential_ORF_Coverage_Residue_Count, 
**							  ORF_Coverage_Fraction, Potential_ORF_Coverage_Fraction
**						   - Now calling QRGenerateORFColumnSql to generate the sql for the ORF columns
**			06/06/2004 mem - Removed the Meets_Minimum_Criteria column from the output
**			07/10/2004 mem - Changed default for @SeparateReplicateDataIDs to 0
**			10/05/2004 mem - Updated for new MTDB schema
**			11/09/2004 mem - Now rounding protein mass to 2 decimal places
**			04/05/2005 mem - Added parameter @VerboseColumnOutput
**			05/25/2005 mem - Renamed output column MonoMassKDa to Mono_Mass_KDa
**			07/25/2006 mem - Now obtaining the protein Description from T_Proteins instead of from an external ORF database
**			11/28/2006 mem - Added parameter @SortMode, which affects the order in which the results are returned
**						   - Now using @SkipCrossTabSqlGeneration=1 when calling QRGenerateCrosstabSql
**			06/04/2007 mem - Added parameters @message and @PreviewSql; changed @Sql to varchar(max); switched to Try/Catch error handling
**			06/13/2007 mem - Expanded the size of @QuantitationIDList to varchar(max)
**			07/05/2007 mem - Shortened @QuantitationIDList when appending to @Description
**			01/24/2008 mem - Added @IncludeProteinDescription and @MinimumPeptidesPerProtein
**
****************************************************/
(
	@QuantitationIDList varchar(max),					-- Comma separated list of Quantitation ID's
	@SeparateReplicateDataIDs tinyint = 0,				-- For quantitation ID's with replicates, include separate details for each replicate
	@ReplicateCountAvgMinimum decimal(9,5) = 1,			-- Ignored if the given QuantitationID only has one MDID defined
	@Description varchar(32)='' OUTPUT,
	@VerboseColumnOutput tinyint = 1,					-- Set to 1 to include all of the output columns; 0 to hide the less commonly used columns
	@SortMode tinyint=2,								-- 0=Unsorted, 1=QID, 2=SampleName, 3=Comment, 4=Job (first job if more than one job), 5=Dataset Acq_Time_Start
	@message varchar(512)='' output,
	@PreviewSql tinyint=0,
	@IncludeProteinDescription tinyint = 1,				-- Set to 1 to include protein descriptions; 0 to exclude them
	@IncludeQID tinyint = 0,							-- Set to 1 to include the Quantitation ID in column QID, just after the Sample Name
	@MinimumPeptidesPerProtein tinyint = 0				-- Set to 2 or higher to exclude proteins with MassTagCountUniqueObserved values less than this number
)
AS 

	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	Declare @Sql varchar(max),
			@ORFColumnSql varchar(2048),
			@ReplicateAndFractionSql varchar(2048)

	Declare @QuantitationID int,
			@MDIDCount int,
			@ReplicateCount int,
			@FractionCount int,
			@TopLevelFractionCount int,
			@HighestMDIDCount int,
			@HighestReplicateCount int,
			@HighestFractionCount int,
			@HighestTopLevelFractionCount int,
			@ERValuesPresent tinyint,
			@DescriptionLong varchar(1024)

	Declare @SourceColName varchar(128),
			@AggregateColName varchar(128),
			@AverageAcrossColumnsEnabled tinyint

	Set @HighestMDIDCount = 0
	Set @HighestReplicateCount = 0
	Set @HighestFractionCount = 0
	Set @HighestTopLevelFractionCount = 0

	Set @SourceColName = 'MT_Abundance'		-- The SourceColName doesn't really matter, but must be defined to call QRGenerateCrossTabSql
	Set @AggregateColName = 'AvgAbu'		-- The AggregateColName doesn't really matter, but must be defined
	Set @ERValuesPresent = 0
	Set @AverageAcrossColumnsEnabled = 0

	Declare @continue int


	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try

		--------------------------------------------------------------
		-- Validate the inputs
		--------------------------------------------------------------
		Set @SeparateReplicateDataIDs  = IsNull(@SeparateReplicateDataIDs, 0)
		Set @ReplicateCountAvgMinimum  = IsNull(@ReplicateCountAvgMinimum, 1)
		Set @Description  = IsNull(@Description, '')
		Set @VerboseColumnOutput  = IsNull(@VerboseColumnOutput, 1)
		Set @SortMode  = IsNull(@SortMode, 2)
		set @message = ''
		Set @PreviewSql  = IsNull(@PreviewSql, 0)
		Set @IncludeProteinDescription  = IsNull(@IncludeProteinDescription, 1)
		Set @IncludeQID = IsNull(@IncludeQID, 0)
		Set @MinimumPeptidesPerProtein  = IsNull(@MinimumPeptidesPerProtein, 0)

		--------------------------------------------------------------
		-- Create a temporary table to hold the QIDs and sorting info
		--------------------------------------------------------------
				
		CREATE TABLE #TmpQIDSortInfo (
			SortKey int identity (1,1),
			QID int NOT NULL)

		--------------------------------------------------------------
		-- Call QRGenerateCrosstabSql to populate CrossTabSql and QuantitationIDListSql
		-- Simultaneously, determine if any of the QuantitationID's have nonzero ER values
		-- We only need QuantitationIDListSql for this stored procedure, but QRGenerateCrosstabSql returns both
		-- We have to define @SourceColName and a few other variables before calling the SP
		-- This SP also populates the #TmpQIDSortInfo temporary table using @QuantitationIDList
		--------------------------------------------------------------

		Set @CurrentLocation = 'Call QRGenerateCrosstabSql'
		--
		Exec @myError = QRGenerateCrosstabSql	
									@QuantitationIDList, 
									@SourceColName,
									@AggregateColName,
									@AverageAcrossColumnsEnabled,
									@SeparateReplicateDataIDs,
									@SortMode,
									@SkipCrossTabSqlGeneration = 1,
									@ERValuesPresent = @ERValuesPresent Output

		If @myError <> 0
		Begin
			print 'Error calling QRGenerateCrosstabSql: ' + Convert(varchar(12), @myError)
			Goto Done
		End

		--------------------------------------------------------------
		-- Determine if any of the QID's have multiple replicates, fractions, or TopLevelFractions
		-- We have to step through the values in @QuantitationIDListSql to do this
		--------------------------------------------------------------
		--
		SELECT @QuantitationID = MIN(QID)-1
		FROM #TmpQIDSortInfo
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		Set @continue = 1
		While @continue = 1
		Begin
			SELECT TOP 1 @QuantitationID = QID
			FROM #TmpQIDSortInfo
			WHERE QID > @QuantitationID
			ORDER BY QID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			If @myRowCount <> 1
				Set @continue = 0
			Else
			Begin
				-- Determine if this QuantitationID has multiple replicates, fractions, or TopLevelFractions
				-- Alternatively, if any of those values are greater than 1, but there is only one entry, set
				-- the count variable greater than 1 so that the columns get displayed anyway
				Set @CurrentLocation = 'Call QRLookupReplicateAndFractionCounts for ' + Convert(varchar(19), @QuantitationID)
				Exec QRLookupReplicateAndFractionCounts @QuantitationID, @ReplicateCount = @ReplicateCount OUTPUT, @FractionCount = @FractionCount OUTPUT, @TopLevelFractionCount = @TopLevelFractionCount OUTPUT

				If @ReplicateCount > @HighestReplicateCount
					Set @HighestReplicateCount = @ReplicateCount

				If @FractionCount > @HighestFractionCount
					Set @HighestFractionCount = @FractionCount

				If @TopLevelFractionCount > @HighestTopLevelFractionCount
					Set @HighestTopLevelFractionCount = @TopLevelFractionCount

				SELECT @MDIDCount = Count(MD_ID)
				FROM T_Quantitation_MDIDs
				WHERE Quantitation_ID = @QuantitationID
				
				If @MDIDCount > @HighestMDIDCount
					Set @HighestMDIDCount = @MDIDCount
			End
		End

		Set @ReplicateAndFractionSql = ''
		If @HighestReplicateCount > 1
		Begin
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QR.ReplicateCountAvg, '
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QR.ReplicateCountStDev, '
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QR.ReplicateCountMax, '
		End

		If @HighestFractionCount > 1
		Begin
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QR.FractionCountAvg, '
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QR.FractionCountMax, '
		End

		If @HighestTopLevelFractionCount > 1
		Begin
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QR.TopLevelFractionCountAvg, '
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QR.TopLevelFractionCountMax, '
		End
		
		-- If highest MDID count is 1, then make sure @ReplicateCountAvgMinimum is at most 1
		If @HighestMDIDCount <=1 And @ReplicateCountAvgMinimum > 1
			Set @ReplicateCountAvgMinimum = 1
		
		--------------------------------------------------------------
		-- Populate @Description
		--------------------------------------------------------------
		If CharIndex(',', @QuantitationIDList) > 1
		Begin
			-- User provided a list of Quantitation ID's
			
			Set @Description = 'QIDs '

			-- Make sure @JobList isn't too long
			If Len(@QuantitationIDList) > 23 - Len(@Description)
				Set @QuantitationIDList = SubString(@QuantitationIDList, 1, 21 - Len(@Description)) + '..'

			-- Append @QuantitationIDList to @Description
			Set @Description = @Description + @QuantitationIDList + ';Pro'
		End
		Else
		Begin
			-- User provided a single quantitation ID
			-- Generate a description for this QuantitationID using the job numbers that its
			-- MDID's correspond plus the text 'Pep' = Peptide
			Exec QRGenerateDescription @QuantitationID, 'Pro', @Description = @Description OUTPUT
		End
		
		
		--------------------------------------------------------------
		-- Construct the sql to return the data
		--------------------------------------------------------------
		
		Set @CurrentLocation = 'Populate @Sql'
		
		-- Generate the sql for the ORF columns in T_Quantitation_Results
		Exec QRGenerateORFColumnSql @ERValuesPresent, @ORFColumnSql = @OrfColumnSql OUTPUT, @IncludeProteinDescription=@IncludeProteinDescription, @IncludeQID=@IncludeQID
		Set @Sql = @ORFColumnSql
		
		Set @Sql = @Sql + ' ' + @ReplicateAndFractionSql								-- Note, if this variable has text, it will end in a comma
		Set @Sql = @Sql + ' Round(IsNull(T_Proteins.Monoisotopic_Mass, 0) / 1000, 2) AS Mono_Mass_KDa'
		If @VerboseColumnOutput <> 0
			Set @Sql = @Sql + ' , QD.Quantitation_ID'
		Set @Sql = @Sql + ' FROM #TmpQIDSortInfo INNER JOIN '
		Set @Sql = @Sql +      ' T_Quantitation_Results QR ON #TmpQIDSortInfo.QID = QR.Quantitation_ID INNER JOIN'
		Set @Sql = @Sql +      ' T_Quantitation_Description QD ON QR.Quantitation_ID = QD.Quantitation_ID LEFT OUTER JOIN'
		Set @Sql = @Sql +      ' T_Proteins ON QR.Ref_ID = T_Proteins.Ref_ID'
		Set @Sql = @Sql + ' WHERE QR.ReplicateCountAvg >= ' + Convert(varchar(19), @ReplicateCountAvgMinimum)
		If @MinimumPeptidesPerProtein > 0
			Set @Sql = @Sql + ' AND QR.MassTagCountUniqueObserved >= ' + Convert(varchar(12), @MinimumPeptidesPerProtein)
		Set @Sql = @Sql + ' ORDER BY #TmpQIDSortInfo.SortKey, QR.Abundance_Average DESC, T_Proteins.Reference'
		
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
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'QRRetrieveProteinsMultiQID')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch

Done:
	--
	Return @myError

GO
GRANT EXECUTE ON [dbo].[QRRetrieveProteinsMultiQID] TO [DMS_SP_User]
GO
