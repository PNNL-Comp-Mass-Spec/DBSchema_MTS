/****** Object:  StoredProcedure [dbo].[QRRetrieveProteinsMultiQID] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE ProcEDURE dbo.QRRetrieveProteinsMultiQID
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
**
****************************************************/
(
	@QuantitationIDList varchar(1024),					-- Comma separated list of Quantitation ID's
	@SeparateReplicateDataIDs tinyint = 0,				-- For quantitation ID's with replicates, include separate details for each replicate
	@ReplicateCountAvgMinimum decimal(9,5) = 1,			-- Ignored if the given QuantitationID only has one MDID defined
	@Description varchar(32)='' OUTPUT,
	@VerboseColumnOutput tinyint = 1,					-- Set to 1 to include all of the output columns; 0 to hide the less commonly used columns
	@SortMode tinyint=2									-- 0=Unsorted, 1=QID, 2=SampleName, 3=Comment, 4=Job (first job if more than one job)
)
AS 

	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	Declare @sql varchar(8000),
			@ORFColumnSql varchar(2048),
			@ReplicateAndFractionSql varchar(1024)

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
		If Len(@QuantitationIDList) > 26 - Len(@Description)
			Set @QuantitationIDList = SubString(@QuantitationIDList, 1, 24 - Len(@Description)) + '..'

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
	-- Generate the sql for the ORF columns in T_Quantitation_Results
	Exec QRGenerateORFColumnSql @ERValuesPresent, @ORFColumnSql = @OrfColumnSql OUTPUT
	Set @sql = @ORFColumnSql
	
	Set @sql = @sql + ' ' + @ReplicateAndFractionSql								-- Note, if this variable has text, it will end in a comma
	Set @sql = @sql + ' Round(IsNull(T_Proteins.Monoisotopic_Mass, 0) / 1000, 2) AS Mono_Mass_KDa'
	If @VerboseColumnOutput <> 0
		Set @sql = @sql + ' , QD.Quantitation_ID'
	Set @sql = @sql + ' FROM #TmpQIDSortInfo INNER JOIN '
	Set @sql = @sql +      ' T_Quantitation_Results QR ON #TmpQIDSortInfo.QID = QR.Quantitation_ID INNER JOIN'
	Set @sql = @sql +      ' T_Quantitation_Description QD ON QR.Quantitation_ID = QD.Quantitation_ID LEFT OUTER JOIN'
	Set @sql = @sql +      ' T_Proteins ON QR.Ref_ID = T_Proteins.Ref_ID'
	Set @sql = @sql + ' WHERE QR.ReplicateCountAvg >= ' + Convert(varchar(19), @ReplicateCountAvgMinimum)
	Set @sql = @sql + ' ORDER BY #TmpQIDSortInfo.SortKey, QR.Abundance_Average DESC, T_Proteins.Reference'
	
	Exec (@sql)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

Done:
	--
	Return @myError


GO
GRANT EXECUTE ON [dbo].[QRRetrieveProteinsMultiQID] TO [DMS_SP_User]
GO
