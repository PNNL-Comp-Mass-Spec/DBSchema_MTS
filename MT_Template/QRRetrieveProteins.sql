/****** Object:  StoredProcedure [dbo].[QRRetrieveProteins] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.QRRetrieveProteins
/****************************************************	
**  Desc: Returns the proteins and associated statistics
**		  for the given QuantitationID
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: QuantitationID value to process
**
**  Auth:	mem
**	Date:	07/30/2003
**			08/01/2003
**			08/15/2003
**			08/18/2003
**			08/26/2003
**			09/17/2003 mem - Now returns the ER_Average and ER_StDev columns if non-zero values are present in ER_Average for @QuantitationID
**			09/20/2003 mem - Added Mass_Error_PPM_Avg column
**			09/22/2003 mem - Added Meets_Minimum_Criteria column
**			11/18/2003 mem - Updated @ERValuesPresent test to use MAX(ABS(ER_Average)) rather than simply MAX(ER_Average)
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
**			07/10/2004 mem - Added Match_Score_Average column
**			10/05/2004 mem - Updated for new MTDB schema
**			11/09/2004 mem - Now rounding protein mass to 2 decimal places
**			04/05/2005 mem - Added parameter @VerboseColumnOutput
**			05/25/2005 mem - Renamed output column MonoMassKDa to Mono_Mass_KDa
**			07/25/2006 mem - Now obtaining the protein Description from T_Proteins instead of from an external ORF database
**			06/05/2007 mem - Added parameters @message and @PreviewSql; switched to Try/Catch error handling
**			10/13/2010 mem - Now passing @MatchScoreMode to QRGenerateORFColumnSql
**
****************************************************/
(
	@QuantitationID int,
	@ReplicateCountAvgMinimum decimal(9,5) = 1,			-- Ignored if the given QuantitationID only has one MDID defined
	@Description varchar(32)='' OUTPUT,
	@VerboseColumnOutput tinyint = 1,					-- Set to 1 to include all of the output columns; 0 to hide the less commonly used columns (at present, this parameter is unused, but is included for symmetry with WebQRRetrievePeptidesMultiQID)
	@message varchar(512)='' output,
	@PreviewSql tinyint=0
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
	
	Declare @MDIDCount int,
			@ReplicateCount int,
			@FractionCount int,
			@TopLevelFractionCount int,
			@ERValuesPresent float
	
	Declare @MatchScoreMode tinyint
	
	Set @MDIDCount = 0
	Set @MatchScoreMode = 0
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		
		-- Lookup Match_Score_Mode for this QuantitationID
		SELECT @MatchScoreMode = IsNull(Match_Score_Mode, 0)
		FROM T_Quantitation_Description
		WHERE Quantitation_ID = @QuantitationID
		
		-- Determine if this QuantitationID has more than one MDID defined
		SELECT @MDIDCount = Count(MD_ID)
		FROM T_Quantitation_MDIDs
		WHERE Quantitation_ID = @QuantitationID
		
		-- Determine if this QuantitationID has any nonzero ER values
		SELECT @ERValuesPresent = MAX(ABS(ER_Average))
		FROM T_Quantitation_Results
		WHERE Quantitation_ID = @QuantitationID
		
		-- If only one MDID, then make sure @ReplicateCountAvgMinimum is at most 1
		If @MDIDCount <=1 AND @ReplicateCountAvgMinimum > 1
			Set @ReplicateCountAvgMinimum = 1
			
		-- Generate a description for this QuantitationID using the job numbers that its
		-- MDID's correspond plus the text 'Pro' = Protein
		Set @CurrentLocation = 'Call QRGenerateDescription'
		Exec QRGenerateDescription @QuantitationID, 'Pro', @Description = @Description OUTPUT

		
		-- Determine if this QuantitationID has multiple replicates, fractions, or TopLevelFractions
		-- Alternatively, if any of those values are greater than 1, but there is only one entry, set
		--  the count variable greater than 1 so that the columns get displayed anyway
		Set @CurrentLocation = 'Call QRLookupReplicateAndFractionCounts'
		Exec QRLookupReplicateAndFractionCounts @QuantitationID, @ReplicateCount = @ReplicateCount OUTPUT, @FractionCount = @FractionCount OUTPUT, @TopLevelFractionCount = @TopLevelFractionCount OUTPUT

		Set @ReplicateAndFractionSql = ''
		If @ReplicateCount > 1
		Begin
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QR.ReplicateCountAvg, '
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QR.ReplicateCountStDev, '
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QR.ReplicateCountMax, '
		End

		If @FractionCount > 1
		Begin
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QR.FractionCountAvg, '
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QR.FractionCountMax, '
		End

		If @TopLevelFractionCount > 1
		Begin
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QR.TopLevelFractionCountAvg, '
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QR.TopLevelFractionCountMax, '
		End

		Set @CurrentLocation = 'Construct the Sql to return the data'
		
		-- Generate the sql for the ORF columns in T_Quantitation_Results
		Set @CurrentLocation = 'Call QRLookupReplicateAndFractionCounts'
		Exec QRGenerateORFColumnSql @ERValuesPresent, @ORFColumnSql = @OrfColumnSql OUTPUT, 
		                            @MatchScoreModeMin=@MatchScoreMode,
		                            @MatchScoreModeMax=@MatchScoreMode
		
		Set @sql = @ORFColumnSql
		
		Set @sql = @sql + ' ' + @ReplicateAndFractionSql								-- Note, if this variable has text, it will end in a comma
		Set @sql = @sql + ' Round(T_Proteins.Monoisotopic_Mass / 1000, 2) AS Mono_Mass_KDa'
		Set @sql = @sql + ' FROM T_Quantitation_Results As QR LEFT OUTER JOIN'
		Set @sql = @sql + '  T_Proteins ON QR.Ref_ID = T_Proteins.Ref_ID'
		Set @sql = @sql + ' INNER JOIN'
		Set @sql = @sql + '  T_Quantitation_Description AS QD ON QR.Quantitation_ID = QD.Quantitation_ID'
		Set @sql = @sql + ' WHERE 	QD.Quantitation_ID = ' + Convert(varchar(19), @QuantitationID) + ' AND '
		Set @sql = @sql + '			QR.ReplicateCountAvg >= ' + Convert(varchar(19), @ReplicateCountAvgMinimum)
		Set @sql = @sql + ' ORDER BY QR.Abundance_Average DESC, T_Proteins.Reference'

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
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'QRRetrieveProteins')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch
	
Done:
	--
	Return @myError


GO
GRANT EXECUTE ON [dbo].[QRRetrieveProteins] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QRRetrieveProteins] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QRRetrieveProteins] TO [MTS_DB_Lite] AS [dbo]
GO
