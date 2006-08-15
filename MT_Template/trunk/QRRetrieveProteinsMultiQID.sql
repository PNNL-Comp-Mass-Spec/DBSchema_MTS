/****** Object:  StoredProcedure [dbo].[QRRetrieveProteinsMultiQID] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.QRRetrieveProteinsMultiQID
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
**
****************************************************/
(
	@QuantitationIDList varchar(1024),					-- Comma separated list of Quantitation ID's
	@SeparateReplicateDataIDs tinyint = 0,				-- For quantitation ID's with replicates, include separate details for each replicate
	@ReplicateCountAvgMinimum decimal(9,5) = 1,			-- Ignored if the given QuantitationID only has one MDID defined
	@Description varchar(32)='' OUTPUT,
	@VerboseColumnOutput tinyint = 1					-- Set to 1 to include all of the output columns; 0 to hide the less commonly used columns (at present, this parameter is unused, but is included for symmetry with WebQRRetrievePeptidesMultiQID)
)
AS 

	Set NoCount On

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
			@ERValuesPresent float,
			@DescriptionLong varchar(1024)

	Declare @CrossTabSql varchar(7000),
			@CrossTabSqlGroupBy varchar(7000),
			@QuantitationIDListSql varchar(1024),
			@SourceColName varchar(128),
			@AggregateColName varchar(128),
			@NullWhenMissing tinyint

	Set @HighestMDIDCount = 0
	Set @HighestReplicateCount = 0
	Set @HighestFractionCount = 0
	Set @HighestTopLevelFractionCount = 0

	Set @SourceColName = 'MT_Abundance'		-- The SourceColName doesn't really matter, but must be defined to call QRGenerateCrossTabSql
	Set @AggregateColName = 'AvgAbu'		-- The AggregateColName doesn't really matter, but must be defined
	Set @NullWhenMissing = 0

	Declare @WorkingList varchar(1024),
			@CommaLoc int

	--------------------------------------------------------------
	-- Call QRGenerateCrosstabSql to populate CrossTabSql and QuantitationIDListSql
	-- We only need QuantitationIDListSql for this stored procedure, but QRGenerateCrosstabSql returns both
	-- We have to define @SourceColName and a few other variables before calling the SP
	--------------------------------------------------------------
	Exec QRGenerateCrosstabSql	@QuantitationIDList, 
								@SourceColName,
								@AggregateColName,
								@NullWhenMissing,
								@SeparateReplicateDataIDs,
								@CrossTabSql = @CrossTabSql Output, 
								@CrossTabSqlGroupBy = @CrossTabSqlGroupBy Output,
								@QuantitationIDListSql = @QuantitationIDListSql Output

	-- Determine if any of the QuantitationID's have nonzero ER values
	-- We have to step through the values in @QuantitationIDListSql to do this
	Set @ERValuesPresent = 0
	Set @WorkingList = @QuantitationIDListSql + ','
	Set @CommaLoc = CharIndex(',', @WorkingList)
	WHILE @CommaLoc > 1
	BEGIN

		Set @QuantitationID = LTrim(Left(@WorkingList, @CommaLoc-1))
		Set @WorkingList = SubString(@WorkingList, @CommaLoc+1, Len(@WorkingList))
		
		-- If the QuantitationID is numeric, and if no ER values have been found yet, then look for ER values
		If IsNumeric(@QuantitationID) = 1 AND @ERValuesPresent = 0
		Begin
			-- Determine if this QuantitationID has any nonzero ER values
			SELECT @ERValuesPresent = MAX(ABS(ER_Average))
			FROM T_Quantitation_Results
			WHERE (Quantitation_ID = @QuantitationID)
		End

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
		
		Set @CommaLoc = CharIndex(',', @WorkingList)
	END

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
	
	-- Generate the sql for the ORF columns in T_Quantitation_Results
	Exec QRGenerateORFColumnSql @ERValuesPresent, @ORFColumnSql = @OrfColumnSql OUTPUT
	
	-- Construct the sql to return the data
	Set @sql = @ORFColumnSql
	
	Set @sql = @sql + ' ' + @ReplicateAndFractionSql								-- Note, if this variable has text, it will end in a comma
	Set @sql = @sql + ' Round(T_Proteins.Monoisotopic_Mass / 1000, 2) AS Mono_Mass_KDa'
	Set @sql = @sql + ' FROM T_Quantitation_Results As QR LEFT OUTER JOIN'
	Set @sql = @sql + '  T_Proteins ON QR.Ref_ID = T_Proteins.Ref_ID'
	Set @sql = @sql + ' INNER JOIN'
	Set @sql = @sql + '  T_Quantitation_Description AS QD ON QR.Quantitation_ID = QD.Quantitation_ID'
	Set @sql = @sql + ' WHERE   QD.Quantitation_ID IN (' + @QuantitationIDListSql + ') AND '
	Set @sql = @sql + '			QR.ReplicateCountAvg >= ' + Convert(varchar(19), @ReplicateCountAvgMinimum)
	Set @sql = @sql + ' ORDER BY QD.SampleName, QR.Abundance_Average DESC, T_Proteins.Reference'
	
	Exec (@sql)
	--
	Return @@Error



GO
GRANT EXECUTE ON [dbo].[QRRetrieveProteinsMultiQID] TO [DMS_SP_User]
GO
