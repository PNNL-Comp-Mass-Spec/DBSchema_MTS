/****** Object:  StoredProcedure [dbo].[QRRetrievePeptides] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.QRRetrievePeptides
/****************************************************	
**  Desc: Returns the peptides and associated statistics
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
**			08/27/2003
**			09/17/2003 mem - Now returns the ER_Average and ER_StDev columns if non-zero values are present in ER_Average for @QuantitationID
**			09/20/2003 mem - Added Scan_Minimum, Scan_Maximum, and Mass_Error_PPM_Avg columns, along with mass tag mass
**			11/09/2003 mem - Added NET_Minimum and NET_Maximum columns
**			11/13/2003 mem - Added Mass_Tag_Mods column
**			11/18/2003 mem - Added 3 charge columns and updated @ERValuesPresent test to use MAX(ABS(QRD.ER)) rather than simply MAX(QRD.ER)
**			11/19/2003 mem - Added High_Normalized_Score field
**			04/09/2004 mem - Added ORF description to output (obtained from ORF DB defined in T_External_Databases)
**						   - Added the Cleavage_State of the peptide
**						   - Added ORF_Count for the peptide
**						   - Now calling QRGenerateORFColumnSql to generate the sql for the ORF columns
**			04/17/2004 mem - Added PMT_Quality_Score field
**			06/06/2004 mem - Now returning the Dynamic_Mod_List and/or Static_Mod_List columns if any of the peptides does not contain 'none' for the list value
**			07/10/2004 mem - Added Member_Count_Used_For_Abundance, ER_Charge_State_Basis_Count, and MT_Match_Score_Avg columns
**						   - Now looking up ORF_Count and PMT_Quality_Score from T_Quantitation_ResultDetails
**			10/05/2004 mem - Updated for new MTDB schema
**			11/09/2004 mem - Renamed the match score columns to SLiC Score and removed some of the legacy, less useful columns
**			01/06/2005 mem - Renamed the PMT ER columns to MT_ER, MT_ER_StDev, and MT_ER_Charge_State_Basis_Count
**			04/05/2005 mem - Added parameter @VerboseColumnOutput
**			05/24/2005 mem - Now returning "Internal_Std" in column Mass_Tag_Mods when Internal_Standard_Match = 1
**			05/25/2005 mem - Added underscores at word boundaries in column QD.SampleName
**			08/25/2005 mem - Added parameter @IncludePrefixAndSuffixResidues, which, when enabled, will cause the peptide sequence displayed to have prefix and suffix residues (must also have @IncludeRefColumn = 1)
**			01/31/2006 mem - Now returning 'Unknown' if the Cleavage_State value is null
**			07/25/2006 mem - Now obtaining the protein Description from T_Proteins instead of from an external ORF database
**			09/07/2006 mem - Now returning column High_Peptide_Prophet_Probability
**			05/28/2007 mem - Now returning column JobCount_Observed_Both_MS_and_MSMS
**			06/05/2007 mem - Added parameters @message and @PreviewSql; switched to Try/Catch error handling
**
****************************************************/
(
	@QuantitationID int,
	@IncludeRefColumn tinyint = 1,
	@Description varchar(32)='' OUTPUT,
	@VerboseColumnOutput tinyint = 1,					-- Set to 1 to include all of the output columns; 0 to hide the less commonly used columns
	@IncludePrefixAndSuffixResidues tinyint = 0,			-- The query is slower if this is enabled
	@message varchar(512)='' output,
	@PreviewSql tinyint=0

)
AS 

	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	Declare @QRDsql varchar(max),
	        @sql varchar(max),
			@ORFColumnSql varchar(2048),
			@ReplicateAndFractionSql varchar(2048)

	Declare	@ReplicateCount int,
			@FractionCount int,
			@TopLevelFractionCount int,
			@ERValuesPresent tinyint,
			@ModsPresent tinyint

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try

		-- Determine if this QuantitationID has any nonzero ER values or modified mass tags
		Set @ERValuesPresent = 0
		Set @ModsPresent = 0
		
		Set @CurrentLocation = 'Call QRLookupOptionalColumns'
		Exec QRLookupOptionalColumns @QuantitationID, 
				@ERValuesPresent = @ERValuesPresent OUTPUT, @ModsPresent = @ModsPresent OUTPUT

		-- Generate a description for this QuantitationID using the job numbers that its
		-- MDID's correspond plus the text 'Pep' = Peptide
		Set @CurrentLocation = 'Call QRGenerateDescription'
		Exec QRGenerateDescription @QuantitationID, 'Pep', @Description = @Description OUTPUT

		-- Determine if this QuantitationID has multiple replicates, fractions, or TopLevelFractions
		-- Alternatively, if any of those values are greater than 1, but there is only one entry, set
		--  the count variable greater than 1 so that the columns get displayed anyway
		Set @CurrentLocation = 'Call QRLookupReplicateAndFractionCounts'
		Exec QRLookupReplicateAndFractionCounts @QuantitationID, @ReplicateCount = @ReplicateCount OUTPUT, @FractionCount = @FractionCount OUTPUT, @TopLevelFractionCount = @TopLevelFractionCount OUTPUT

		Set @ReplicateAndFractionSql = ''
		If @ReplicateCount > 1
		Begin
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.ReplicateCountAvg, '
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.ReplicateCountMin, '
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.ReplicateCountMax, '
		End

		If @FractionCount > 1
		Begin
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.FractionCountAvg, '
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.FractionMin, '
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.FractionMax, '
		End

		If @TopLevelFractionCount > 1
		Begin
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.TopLevelFractionCount, '
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.TopLevelFractionMin, '
			Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.TopLevelFractionMax, '
		End

		Set @CurrentLocation = 'Populate @QRDSql'

		Set @QRDsql = ''
		Set @QRDsql = @QRDsql + ' QRD.Mass_Tag_ID, CASE WHEN QRD.Internal_Standard_Match = 1 THEN ''Internal_Std'' ELSE QRD.Mass_Tag_Mods END AS Mass_Tag_Mods,'
		Set @QRDsql = @QRDsql + ' Round(QRD.MT_Abundance,4) As MT_Abundance, Round(QRD.MT_Abundance_StDev,4) As MT_Abundance_StDev,'
		If @VerboseColumnOutput <> 0
			Set @QRDsql = @QRDsql + ' QRD.Member_Count_Used_For_Abundance, '

		Set @QRDsql = @QRDsql + ' Round(QRD.MT_Match_Score_Avg,3) AS MT_SLiC_Score_Avg, '
		If @VerboseColumnOutput <> 0
			Set @QRDsql = @QRDsql + ' Round(QRD.MT_Del_Match_Score_Avg,3) AS MT_Del_SLiC_Avg,'

		If @ERValuesPresent > 0
		Begin
			Set @QRDsql = @QRDsql + ' QRD.ER AS MT_ER,'
			Set @QRDsql = @QRDsql + ' QRD.ER_StDev AS MT_ER_StDev,'
			Set @QRDsql = @QRDsql + ' QRD.ER_Charge_State_Basis_Count,'
		End

		If @IncludeRefColumn <> 0 AND @IncludePrefixAndSuffixResidues <> 0
			Set @QRDsql = @QRDsql + ' MTPM.Peptide_Sequence AS Peptide,'
		Else
			Set @QRDsql = @QRDsql + ' MT.Peptide,'
		
		Set @QRDsql = @QRDsql + ' Round(MT.Monoisotopic_Mass,5) As Monoisotopic_Mass, '
		Set @QRDsql = @QRDsql + ' Round(MT.High_Normalized_Score,3) As [High_MS/MS_Score_(XCorr)], '
		Set @QRDsql = @QRDsql + ' Round(MT.High_Discriminant_Score,3) As High_Discriminant_Score, '
		Set @QRDsql = @QRDsql + ' Round(MT.High_Peptide_Prophet_Probability,3) As High_Peptide_Prophet_Probability, '
		Set @QRDsql = @QRDsql + ' Round(QRD.PMT_Quality_Score,2) As PMT_Quality_Score,'
		Set @QRDsql = @QRDsql + ' QRD.JobCount_Observed_Both_MS_and_MSMS,'

		If @ModsPresent > 0
			Set @QRDsql = @QRDsql + ' MT.Mod_Description,'

		Set @QRDsql = @QRDsql + ' QRD.ORF_Count AS Protein_Count, IsNull(CSN.Cleavage_State_Name, ''Unknown'') AS Cleavage_State_Name,'

		If @VerboseColumnOutput <> 0
		Begin
			Set @QRDsql = @QRDsql + ' QRD.UMC_MatchCount_Avg,'
			Set @QRDsql = @QRDsql + ' QRD.Scan_Minimum, QRD.Scan_Maximum,'
			Set @QRDsql = @QRDsql + ' Round(QRD.NET_Minimum,3) As NET_Minimum, Round(QRD.NET_Maximum,3) As NET_Maximum,'
			Set @QRDsql = @QRDsql + ' Round(QRD.Class_Stats_Charge_Basis_Avg, 2) As Charge_Basis_Avg,'
			Set @QRDsql = @QRDsql + ' QRD.Charge_State_Min, QRD.Charge_State_Max,'
			Set @QRDsql = @QRDsql + ' Round(QRD.Mass_Error_PPM_Avg,2) AS MT_Mass_Error_PPM_Avg,'
			Set @QRDsql = @QRDsql + ' Round(QRD.NET_Error_Obs_Avg,3) AS NET_Error_Obs_Avg, Round(QRD.NET_Error_Pred_Avg,3) AS NET_Error_Pred_Avg,'
		End
		
		Set @QRDsql = @QRDsql + ' ' + @ReplicateAndFractionSql					-- Note, if this variable has text, it will end in a comma
		If @IncludeRefColumn <> 0 AND @VerboseColumnOutput <> 0
			Set @QRDsql = @QRDsql + '  QRD.Used_For_Abundance_Computation'		-- Can only display the Used_For_Abundance_Computation column if displaying protein Refs; otherwise, this doesn't make sense
		Else
			Set @QRDsql = SubString(@QRDsql, 0, Len(@QRDsql))					-- Need to remove the trailing comma

		Set @QRDsql = @QRDsql + ' FROM T_Quantitation_Description AS QD INNER JOIN'
		Set @QRDsql = @QRDsql + ' T_Quantitation_Results As QR ON '
		Set @QRDsql = @QRDsql + ' QD.Quantitation_ID = QR.Quantitation_ID INNER JOIN'
		Set @QRDsql = @QRDsql + ' T_Quantitation_ResultDetails As QRD ON '
		Set @QRDsql = @QRDsql + ' QR.QR_ID = QRD.QR_ID INNER JOIN'
		Set @QRDsql = @QRDsql + ' T_Mass_Tags AS MT ON '
		Set @QRDsql = @QRDsql + ' QRD.Mass_Tag_ID = MT.Mass_Tag_ID LEFT OUTER JOIN'
		
		If @IncludePrefixAndSuffixResidues <> 0
		Begin
			Set @QRDsql = @QRDsql + ' V_Mass_Tag_to_Protein_Map_Full_Sequence AS MTPM ON'
			Set @QRDsql = @QRDsql + ' MT.Mass_Tag_ID = MTPM.Mass_Tag_ID AND QR.Ref_ID = MTPM.Ref_ID'
		End
		Else
		Begin
			Set @QRDsql = @QRDsql + ' T_Mass_Tag_to_Protein_Map AS MTPM ON '
			Set @QRDsql = @QRDsql + ' MT.Mass_Tag_ID = MTPM.Mass_Tag_ID AND QR.Ref_ID = MTPM.Ref_ID'
		End

		Set @QRDsql = @QRDsql + ' LEFT OUTER JOIN T_Peptide_Cleavage_State_Name AS CSN ON'
		Set @QRDsql = @QRDsql + ' MTPM.Cleavage_State = CSN.Cleavage_State'

		-- Construct the sql to return the data
		Set @CurrentLocation = 'Populate @Sql'
		
		Set @sql = ''
		If @IncludeRefColumn <> 0
		Begin	
			-- Generate the sql for the ORF columns in T_Quantitation_Results
			Exec QRGenerateORFColumnSql @ORFColumnSql = @OrfColumnSql OUTPUT

			Set @sql = @OrfColumnSql 

			-- Future: Return a protein confidence value here
			--			We used to return Meets_Minimum_Criteria, but that column is no longer used
			-- Set @sql = @sql + '  QR.Meets_Minimum_Criteria,'
			Set @sql = @sql +    @QRDsql
			Set @sql = @sql + '   LEFT OUTER JOIN'
			Set @sql = @sql + '  T_Proteins ON'
			Set @sql = @sql + '  QR.Ref_ID = T_Proteins.Ref_ID'
			Set @sql = @sql + ' WHERE QD.Quantitation_ID = ' + Convert(varchar(19), @QuantitationID)
			Set @sql = @sql + ' ORDER BY T_Proteins.Reference, QRD.Mass_Tag_ID'
		End
		Else
		Begin
			Set @sql = @sql + ' SELECT DISTINCT'
			Set @sql = @sql + '  QD.SampleName AS Sample_Name,'
			Set @sql = @sql +    @QRDsql
			Set @sql = @sql + ' WHERE QD.Quantitation_ID = ' + Convert(varchar(19), @QuantitationID)
			Set @sql = @sql + ' ORDER BY QRD.Mass_Tag_ID'
		End


		If @PreviewSql <> 0
			Print @Sql
		Else
			Exec (@Sql)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'QRRetrievePeptides')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch

	
Done:
	--
	Return @myError


GO
GRANT EXECUTE ON [dbo].[QRRetrievePeptides] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QRRetrievePeptides] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QRRetrievePeptides] TO [MTS_DB_Lite] AS [dbo]
GO
