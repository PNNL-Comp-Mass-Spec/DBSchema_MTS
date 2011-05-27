/****** Object:  StoredProcedure [dbo].[QRRetrievePeptidesMultiQID] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.QRRetrievePeptidesMultiQID
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
**			11/28/2006 mem - Added parameter @SortMode, which affects the order in which the results are returned
**						   - Now using @SkipCrossTabSqlGeneration=1 when calling QRGenerateCrosstabSql
**			12/06/2006 mem - No longer using @SortMode if @IncludeRefColumn = 0 (see explanation regarding #TmpQIDSortInfo.SortKey and SELECT DISTINCT)
**			05/28/2007 mem - Now returning column JobCount_Observed_Both_MS_and_MSMS
**			06/05/2007 mem - Added parameters @message and @PreviewSql; changed @QRDsql and @Sql to varchar(max); switched to Try/Catch error handling
**			06/13/2007 mem - Expanded the size of @QuantitationIDList to varchar(max)
**			07/05/2007 mem - Shortened @QuantitationIDList when appending to @Description
**			08/12/2008 mem - Now including column Min_Log_EValue if X!Tandem-based peptides are present in T_Mass_Tags
**			10/22/2008 mem - Added parameter @ChangeCommasToSemicolons
**			12/19/2008 mem - Added @IncludeQID
**
****************************************************/
(
	@QuantitationIDList varchar(max),					-- Comma separated list of Quantitation ID's
	@SeparateReplicateDataIDs tinyint = 0,				-- For quantitation ID's with replicates, include separate details for each replicate
	@IncludeRefColumn tinyint = 1,
	@Description varchar(32)='' OUTPUT,
	@VerboseColumnOutput tinyint = 1,					-- Set to 1 to include all of the output columns; 0 to hide the less commonly used columns
	@IncludePrefixAndSuffixResidues tinyint = 0,		-- The query is slower if this is enabled
	@SortMode tinyint=2,								-- 0=Unsorted, 1=QID, 2=SampleName, 3=Comment, 4=Job (first job if more than one job)
	@message varchar(512)='' output,
	@PreviewSql tinyint=0,
	@IncludeProteinDescription tinyint = 1,				-- Set to 1 to include protein descriptions; 0 to exclude them
	@IncludeQID tinyint = 0,								-- Set to 1 to include the Quantitation ID in column QID, just after the Sample Name
	@ChangeCommasToSemicolons tinyint = 0				-- Replaces commas with semicolons in various text fields, including: SampleName, Reference, Protein Description, and Mod_Description
)
AS 

	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	Declare @QRDsql varchar(max),
			@Sql varchar(max),
			@ORFColumnSql varchar(2048),
			@ReplicateAndFractionSql varchar(2048)

	Declare	@QuantitationID int,
			@ReplicateCount int,
			@FractionCount int,
			@TopLevelFractionCount int,
			@HighestReplicateCount int,
			@HighestFractionCount int,
			@HighestTopLevelFractionCount int,
			@ERValuesPresent tinyint,
			@ModsPresent tinyint,
			@XTandemDataPresent tinyint,
			@DescriptionLong varchar(1024)

	Declare @SourceColName varchar(128),
			@AggregateColName varchar(128),
			@AverageAcrossColumnsEnabled tinyint

	Declare @MatchScoreModeMin tinyint = 0,
	        @MatchScoreModeMax tinyint = 0

	Set @HighestReplicateCount = 0
	Set @HighestFractionCount = 0
	Set @HighestTopLevelFractionCount = 0

	Set @SourceColName = 'MT_Abundance'		-- The SourceColName doesn't really matter, but must be defined
	Set @AggregateColName = 'AvgAbu'		-- The AggregateColName doesn't really matter, but must be defined
	Set @AverageAcrossColumnsEnabled = 0
	Set @ERValuesPresent = 0
	Set @ModsPresent = 0
	Set @XTandemDataPresent = 0

	Declare @continue int

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try

		--------------------------------------------------------------
		-- Validate the inputs
		--------------------------------------------------------------
		--
		Set @SeparateReplicateDataIDs = IsNull(@SeparateReplicateDataIDs, 0)
		Set @IncludeRefColumn = IsNull(@IncludeRefColumn, 1)
		Set @Description = ''
		Set @VerboseColumnOutput = IsNull(@VerboseColumnOutput, 1)
		Set @IncludePrefixAndSuffixResidues = IsNull(@IncludePrefixAndSuffixResidues, 0)
		Set @SortMode = IsNull(@SortMode, 2)
		Set @message = ''
		Set @PreviewSql = IsNull(@PreviewSql, 0)
		Set @IncludeProteinDescription = IsNull(@IncludeProteinDescription, 1)
		Set @IncludeQID = IsNull(@IncludeQID, 0)
		Set @ChangeCommasToSemicolons = IsNull(@ChangeCommasToSemicolons, 0)
	
		--------------------------------------------------------------
		-- Create a temporary table to hold the QIDs and sorting info
		--------------------------------------------------------------
				
		CREATE TABLE #TmpQIDSortInfo (
			SortKey int identity (1,1),
			QID int NOT NULL)

		--------------------------------------------------------------
		-- Call QRGenerateCrosstabSql to populate CrossTabSql and QuantitationIDListSql
		-- Simultaneously, determine if any of the QuantitationID's have nonzero ER values and
		--  if any of the QID's have peptides with modifications
		-- We only need QuantitationIDListSql for this stored procedure, but QRGenerateCrosstabSql returns it and CrossTabSql
		-- We have to define @SourceColName and a few other variables before calling the SP
		-- This SP also populates the #TmpQIDSortInfo temporary table using @QuantitationIDList
		--------------------------------------------------------------
		
		Set @CurrentLocation = 'Call QRGenerateCrosstabSql'
		Exec @myError = QRGenerateCrosstabSql	
									@QuantitationIDList, 
									@SourceColName,
									@AggregateColName,
									@AverageAcrossColumnsEnabled,
									@SeparateReplicateDataIDs,
									@SortMode,
									@SkipCrossTabSqlGeneration = 1,
									@ERValuesPresent = @ERValuesPresent Output, 
									@ModsPresent = @ModsPresent Output,
									@XTandemDataPresent = @XTandemDataPresent Output

		If @myError <> 0
		Begin
			print 'Error calling QRGenerateCrosstabSql: ' + Convert(varchar(12), @myError)
			Goto Done
		End

		--------------------------------------------------------------
		-- Examine the Match_Score_Mode values for the specified QuantitationIDs
		--------------------------------------------------------------
		--
		SELECT @MatchScoreModeMin = MIN(IsNull(Match_Score_Mode, 0)),
		       @MatchScoreModeMax = MAX(IsNull(Match_Score_Mode, 0))
		FROM T_Quantitation_Description QD
		     INNER JOIN #TmpQIDSortInfo
		       ON QD.Quantitation_ID = #TmpQIDSortInfo.QID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		--------------------------------------------------------------
		-- Determine if any of the QID's have multiple replicates, fractions, or TopLevelFractions
		-- We have to step through the values in #TmpQIDSortInfo
		--------------------------------------------------------------
		--
		SELECT @QuantitationID = MIN(QID)-1
		FROM #TmpQIDSortInfo
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		Set @continue = 1
		WHILE @continue = 1
		BEGIN
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
			End
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
			Set @Description = @Description + @QuantitationIDList + ';Pep'
		End
		Else
		Begin
			-- User provided a single quantitation ID
			-- Generate a description for this QuantitationID using the job numbers that its
			-- MDID's correspond plus the text 'Pep' = Peptide
			Exec QRGenerateDescription @QuantitationID, 'Pep', @Description = @Description OUTPUT
		End
		
		--------------------------------------------------------------
		-- Generate the SQL to return the results
		--------------------------------------------------------------

		Set @CurrentLocation = 'Populate @QRDsql'

		Set @QRDsql = ''
		Set @QRDsql = @QRDsql + ' QRD.Mass_Tag_ID, CASE WHEN QRD.Internal_Standard_Match = 1 THEN ''Internal_Std'' ELSE QRD.Mass_Tag_Mods END AS Mass_Tag_Mods,'
		Set @QRDsql = @QRDsql + ' Round(QRD.MT_Abundance,4) As MT_Abundance, Round(QRD.MT_Abundance_StDev,4) As MT_Abundance_StDev,'
		If @VerboseColumnOutput <> 0
			Set @QRDsql = @QRDsql + ' QRD.Member_Count_Used_For_Abundance, '


		Set @QRDsql = @QRDsql + ' Round(QRD.MT_Match_Score_Avg,3) '
		If @MatchScoreModeMin = 0 And @MatchScoreModeMax = 0
			Set @QRDsql = @QRDsql + 'AS MT_SLiC_Score, '
		Else
		Begin
			If @MatchScoreModeMin >= 1 And @MatchScoreModeMax >= 1
				Set @QRDsql = @QRDsql + 'AS MT_STAC_Score, '
			Else
				Set @QRDsql = @QRDsql + 'AS MT_STAC_or_SLiC_Score, '
		End
		
		If @VerboseColumnOutput <> 0
		Begin
			Set @QRDsql = @QRDsql + ' Round(QRD.MT_Del_Match_Score_Avg,3) '
			If @MatchScoreModeMin = 0 And @MatchScoreModeMax = 0
				Set @QRDsql = @QRDsql + 'AS MT_Del_SLiC,'
			Else
			Begin
				If @MatchScoreModeMin >= 1 And @MatchScoreModeMax >= 1
					Set @QRDsql = @QRDsql + 'AS MT_Del_STAC,'
				Else
					Set @QRDsql = @QRDsql + 'AS MT_Del_STAC_or_SLiC,'
			End
		End
	
		If @MatchScoreModeMin > 0 Or @MatchScoreModeMax > 0
		Begin
			Set @QRDsql = @QRDsql + ' Round(QRD.MT_Uniqueness_Probability_Avg, 3) AS MT_Uniqueness_Probability,'
			Set @QRDsql = @QRDsql + ' Round(QRD.MT_FDR_Threshold_Avg, 4) AS MT_FDR_Threshold,'
		End
		
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

		If @XTandemDataPresent > 0
			Set @QRDsql = @QRDsql + ' Round(IsNull(MT.Min_Log_EValue, 0), 3) AS XTandem_Min_Log_EValue,'

		Set @QRDsql = @QRDsql + ' Round(QRD.PMT_Quality_Score,2) As PMT_Quality_Score,'
		Set @QRDsql = @QRDsql + ' QRD.JobCount_Observed_Both_MS_and_MSMS,'

		If @ModsPresent > 0
		Begin
			If @ChangeCommasToSemicolons = 0
				Set @QRDsql = @QRDsql + ' MT.Mod_Description,'
			Else
				Set @QRDsql = @QRDsql + ' Replace(MT.Mod_Description, '','', '';'') AS Mod_Description,'
		End
		
		Set @QRDsql = @QRDsql + ' QRD.ORF_Count AS Protein_Count, IsNull(CSN.Cleavage_State_Name, ''Unknown'') AS Cleavage_State_Name,'

		If @VerboseColumnOutput <> 0
		Begin
			Set @QRDsql = @QRDsql + ' QRD.UMC_MatchCount_Avg AS UMC_MatchCount,'
			Set @QRDsql = @QRDsql + ' QRD.Scan_Minimum, QRD.Scan_Maximum,'
			Set @QRDsql = @QRDsql + ' Round(QRD.NET_Minimum,3) As NET_Minimum, Round(QRD.NET_Maximum,3) As NET_Maximum,'
			Set @QRDsql = @QRDsql + ' Round(QRD.Class_Stats_Charge_Basis_Avg, 2) As Charge_Basis,'
			Set @QRDsql = @QRDsql + ' QRD.Charge_State_Min, QRD.Charge_State_Max,'
			Set @QRDsql = @QRDsql + ' Round(QRD.Mass_Error_PPM_Avg,2) AS MT_Mass_Error_PPM,'
			Set @QRDsql = @QRDsql + ' Round(QRD.NET_Error_Obs_Avg,3) AS NET_Error_Obs, Round(QRD.NET_Error_Pred_Avg,3) AS NET_Error_Pred,'
		End
		
		Set @QRDsql = @QRDsql + ' ' + @ReplicateAndFractionSql					-- Note, if this variable has text, it will end in a comma
		If @IncludeRefColumn <> 0 AND @VerboseColumnOutput <> 0
			Set @QRDsql = @QRDsql + '  QRD.Used_For_Abundance_Computation,'		-- Can only display the Used_For_Abundance_Computation column if displaying protein Refs; otherwise, this doesn't make sense
		
		If @VerboseColumnOutput <> 0
			Set @QRDsql = @QRDsql + ' QD.Quantitation_ID'
		else
			Set @QRDsql = SubString(@QRDsql, 0, Len(@QRDsql))					-- Need to remove the trailing comma
			
		Set @QRDsql = @QRDsql + ' FROM #TmpQIDSortInfo INNER JOIN '
		Set @QRDsql = @QRDsql +      ' T_Quantitation_Description QD ON #TmpQIDSortInfo.QID = QD.Quantitation_ID INNER JOIN'
		Set @QRDsql = @QRDsql +      ' T_Quantitation_Results QR ON QD.Quantitation_ID = QR.Quantitation_ID INNER JOIN'
		Set @QRDsql = @QRDsql +      ' T_Quantitation_ResultDetails QRD ON QR.QR_ID = QRD.QR_ID INNER JOIN'
		Set @QRDsql = @QRDsql +      ' T_Mass_Tags MT ON QRD.Mass_Tag_ID = MT.Mass_Tag_ID LEFT OUTER JOIN'
		
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

		--------------------------------------------------------------
		-- Construct the sql to return the data
		--------------------------------------------------------------
		
		Set @CurrentLocation = 'Populate @Sql'
		
		Set @Sql = ''
		If @IncludeRefColumn <> 0
		Begin	

			-- Generate the sql for the ORF columns in T_Quantitation_Results
			Exec QRGenerateORFColumnSql @ORFColumnSql = @OrfColumnSql OUTPUT,
										@IncludeProteinDescription = @IncludeProteinDescription,
                                        @IncludeQID=@IncludeQID,
										@ChangeCommasToSemicolons = @ChangeCommasToSemicolons,
										@MatchScoreModeMin=@MatchScoreModeMin,
										@MatchScoreModeMax=@MatchScoreModeMax

			Set @Sql = @OrfColumnSql 

			-- Future: Return a protein confidence value here
			--			We used to return Meets_Minimum_Criteria, but that column is no longer used
			-- Set @Sql = @Sql + '  QR.Meets_Minimum_Criteria,'
			Set @Sql = @Sql +    @QRDsql
			Set @Sql = @Sql + '   LEFT OUTER JOIN'
			Set @Sql = @Sql + '  T_Proteins ON'
			Set @Sql = @Sql + '  QR.Ref_ID = T_Proteins.Ref_ID'
			Set @Sql = @Sql + ' ORDER BY #TmpQIDSortInfo.SortKey, T_Proteins.Reference, QRD.Mass_Tag_ID'
		End
		Else
		Begin
			-- Note: We cannot order by #TmpQIDSortInfo.SortKey since we're using SELECT DISTINCT here
			--  and Sql server cannot order by a column if the column is not included in the output
			Set @Sql = @Sql + ' SELECT DISTINCT'
			If @ChangeCommasToSemicolons = 0
				Set @Sql = @Sql + '  QD.SampleName AS Sample_Name,'
			Else
				Set @Sql = @Sql + '  Replace(QD.SampleName, '','', '';'') AS Sample_Name,'
			
			Set @Sql = @Sql +    @QRDsql
			Set @Sql = @Sql + ' ORDER BY QRD.Mass_Tag_ID'
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
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'QRRetrievePeptidesMultiQID')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch

	
Done:
	--
	Return @myError


GO
GRANT EXECUTE ON [dbo].[QRRetrievePeptidesMultiQID] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QRRetrievePeptidesMultiQID] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QRRetrievePeptidesMultiQID] TO [MTS_DB_Lite] AS [dbo]
GO
