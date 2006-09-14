/****** Object:  StoredProcedure [dbo].[QRRetrievePeptidesMultiQID] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.QRRetrievePeptidesMultiQID
/****************************************************	
**  Desc: Returns the peptides and associated statistics
**		    for the given list of QuantitationID's
**        This information is identical to that returned by QRRetrievePeptides,
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
**			11/18/2003 mem - Added 3 charge columns and updated @ERValuesPresent test to use MAX(ABS(QRD.ER)) rather than simply MAX(QRD.ER)
**			11/19/2003 mem - Added High_Normalized_Score field
**			04/09/2004 mem - Added ORF description to output (obtained from ORF DB defined in T_External_Databases)
**						   -  Added the Cleavage_State of the peptide
**						   - Added ORF_Count for the peptide
**						   - Now calling QRGenerateORFColumnSql to generate the sql for the ORF columns
**			04/17/2004 mem - Added PMT_Quality_Score field
**			06/06/2004 mem - Now returning the Dynamic_Mod_List and/or Static_Mod_List columns if any of the peptides does not contain 'none' for the list value
**			07/10/2004 mem - Added Member_Count_Used_For_Abundance, ER_Charge_State_Basis_Count, and MT_Match_Score_Avg columns
**						   - Now looking up ORF_Count and PMT_Quality_Score from T_Quantitation_ResultDetails
**						   - Changed default for @SeparateReplicateDataIDs to 0
**			10/05/2004 mem - Updated for new MTDB schema
**			11/09/2004 mem - Renamed the match score columns to SLiC Score and removed some of the legacy, less useful columns
**			01/06/2005 mem - Renamed the PMT ER columns to MT_ER, MT_ER_StDev, and MT_ER_Charge_State_Basis_Count
**			04/05/2005 mem - Added parameter @VerboseColumnOutput
**			05/24/2005 mem - Now returning "Internal_Std" in column Mass_Tag_Mods when Internal_Standard_Match = 1
**			08/25/2005 mem - Added parameter @IncludePrefixAndSuffixResidues, which, when enabled, will cause the peptide sequence displayed to have prefix and suffix residues (must also have @IncludeRefColumn = 1)
**			01/31/2006 mem - Now returning 'Unknown' if the Cleavage_State value is null
**			07/25/2006 mem - Now obtaining the protein Description from T_Proteins instead of from an external ORF database
**			09/07/2006 mem - Now returning column High_Peptide_Prophet_Probability
**
****************************************************/
(
	@QuantitationIDList varchar(1024),					-- Comma separated list of Quantitation ID's
	@SeparateReplicateDataIDs tinyint = 0,				-- For quantitation ID's with replicates, include separate details for each replicate
	@IncludeRefColumn tinyint = 1,
	@Description varchar(32)='' OUTPUT,
	@VerboseColumnOutput tinyint = 1,					-- Set to 1 to include all of the output columns; 0 to hide the less commonly used columns
	@IncludePrefixAndSuffixResidues tinyint = 0			-- The query is slower if this is enabled
)
AS 

	Set NoCount On

	Declare @QRDsql varchar(2000),
			@sql varchar(8000),
			@ORFColumnSql varchar(2048),
			@ReplicateAndFractionSql varchar(1024)

	Declare	@QuantitationID int,
			@ReplicateCount int,
			@FractionCount int,
			@TopLevelFractionCount int,
			@HighestReplicateCount int,
			@HighestFractionCount int,
			@HighestTopLevelFractionCount int,
			@ERValuesPresent tinyint,
			@ModsPresent tinyint,
			@DescriptionLong varchar(1024)

	Declare @CrossTabSql varchar(7000),
			@CrossTabSqlGroupBy varchar(7000),
			@QuantitationIDListSql varchar(1024),
			@SourceColName varchar(128),
			@AggregateColName varchar(128),
			@NullWhenMissing tinyint

	Set @HighestReplicateCount = 0
	Set @HighestFractionCount = 0
	Set @HighestTopLevelFractionCount = 0

	Set @SourceColName = 'MT_Abundance'		-- The SourceColName doesn't really matter, but must be defined
	Set @AggregateColName = 'AvgAbu'		-- The AggregateColName doesn't really matter, but must be defined
	Set @NullWhenMissing = 0
	Set @ERValuesPresent = 0
	Set @ModsPresent = 0

	Declare @WorkingList varchar(1024),
			@CommaLoc int

	--------------------------------------------------------------
	-- Call QRGenerateCrosstabSql to populate CrossTabSql and QuantitationIDListSql
	-- Simultaneously, determine if any of the QuantitationID's have nonzero ER values and
	--  if any of the QID's have peptides with modifications
	-- We only need QuantitationIDListSql for this stored procedure, but QRGenerateCrosstabSql returns it and CrossTabSql
	-- We have to define @SourceColName and a few other variables before calling the SP
	--------------------------------------------------------------
	Exec QRGenerateCrosstabSql	@QuantitationIDList, 
								@SourceColName,
								@AggregateColName,
								@NullWhenMissing,
								@SeparateReplicateDataIDs,
								@CrossTabSql = @CrossTabSql Output, 
								@CrossTabSqlGroupBy = @CrossTabSqlGroupBy Output,
								@QuantitationIDListSql = @QuantitationIDListSql Output,
								@ERValuesPresent = @ERValuesPresent Output, 
								@ModsPresent = @ModsPresent Output

	-- Determine if any of the QID's have multiple replicates, fractions, or TopLevelFractions
	-- We have to step through the values in @QuantitationIDListSql to do this
	Set @WorkingList = @QuantitationIDListSql + ','
	Set @CommaLoc = CharIndex(',', @WorkingList)
	WHILE @CommaLoc > 1
	BEGIN

		Set @QuantitationID = LTrim(Left(@WorkingList, @CommaLoc-1))
		Set @WorkingList = SubString(@WorkingList, @CommaLoc+1, Len(@WorkingList))

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

		Set @CommaLoc = CharIndex(',', @WorkingList)
	END

	Set @ReplicateAndFractionSql = ''
	If @HighestReplicateCount > 1
	Begin
		Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.ReplicateCountAvg, '
		Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.ReplicateCountMin, '
		Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.ReplicateCountMax, '
	End

	If @HighestFractionCount > 1
	Begin
		Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.FractionCountAvg, '
		Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.FractionMin, '
		Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.FractionMax, '
	End

	If @HighestTopLevelFractionCount > 1
	Begin
		Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.TopLevelFractionCount, '
		Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.TopLevelFractionMin, '
		Set @ReplicateAndFractionSql = @ReplicateAndFractionSql + 'QRD.TopLevelFractionMax, '
	End
	
	If CharIndex(',', @QuantitationIDList) > 1
	 Begin
		-- User provided a list of Quantitation ID's
		
		Set @Description = 'QIDs '

		-- Make sure @JobList isn't too long
		If Len(@QuantitationIDList) > 26 - Len(@Description)
			Set @QuantitationIDList = SubString(@QuantitationIDList, 1, 24 - Len(@Description)) + '..'

		-- Append @QuantitationIDList to @Description
		Set @Description = @Description + @QuantitationIDList + ';Pep'
	 End
	Else
	 Begin
		-- User provided a single quantitation ID
		-- Generate a description for this QuantitationID using the job numbers that its
		-- MDID's correspond plus the text 'Pep' = Peptide
		Exec QRGenerateDescription @QuantitationID, 'Pep', @Description = @Description OUTPUT
	 End
	
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
	Set @QRDsql = @QRDsql + ' QD.Quantitation_ID = QR.Quantitation_ID '
	Set @QRDsql = @QRDsql + '  INNER JOIN'
	Set @QRDsql = @QRDsql + ' T_Quantitation_ResultDetails As QRD ON '
	Set @QRDsql = @QRDsql + ' QR.QR_ID = QRD.QR_ID INNER JOIN'
	Set @QRDsql = @QRDsql + ' T_Mass_Tags AS MT ON'
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
		Set @sql = @sql + ' WHERE QD.Quantitation_ID IN (' + @QuantitationIDListSql + ')'
		Set @sql = @sql + ' ORDER BY QD.SampleName, T_Proteins.Reference, QRD.Mass_Tag_ID'
	  End
	Else
	  Begin
		Set @sql = @sql + ' SELECT DISTINCT'
		Set @sql = @sql + '  QD.SampleName,'
		Set @sql = @sql +    @QRDsql
		Set @sql = @sql + ' WHERE QD.Quantitation_ID IN (' + @QuantitationIDListSql + ')'
		Set @sql = @sql + ' ORDER BY QD.SampleName, QRD.Mass_Tag_ID'
	  End

	Exec (@sql)

	--
	Return @@Error


GO
GRANT EXECUTE ON [dbo].[QRRetrievePeptidesMultiQID] TO [DMS_SP_User]
GO
