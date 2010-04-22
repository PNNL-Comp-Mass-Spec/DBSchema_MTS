/****** Object:  StoredProcedure [dbo].[LookupQuantitationDefaults] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.LookupQuantitationDefaults
/****************************************************	
**
**  Desc:	Looks up the default values to use for Q Rollup given the MDID value
**
**  Return values: 0 if success, otherwise, error code
**
**  Auth:	mem
**	Date:	08/12/2005
**			09/06/2006 mem - Added parameter @MinimumPeptideProphetProbability
**			06/07/2007 mem - Added parameter @MaximumMatchesPerUMCToKeep
**						   - Updated to allow for wildcards in T_Quantitation_Defaults.Instrument_Name
**						   - Switched to Try/Catch error handling
**			06/08/2007 mem - Updated to use the minimum score values defined in T_Match_Making_Description if they are larger than the defaults defined for this instrument
**
****************************************************/
(
	@MDID int,
	@message varchar(512) = '' output,
	
	@Fraction_Highest_Abu_To_Use real output,
	@Normalize_To_Standard_Abundances tinyint output,
	@Standard_Abundance_Min float output,
	@Standard_Abundance_Max float output,

	@UMCAbundanceMode tinyint output,
	@Expression_Ratio_Mode tinyint output,

	@MinimumHighNormalizedScore real output,
	@MinimumHighDiscriminantScore real output,
	@MinimumPMTQualityScore real output,
	
	@MinimumPeptideLength tinyint output,
	@MinimumMatchScore real output,
	@MinimumDelMatchScore real output,

	@MinimumPeptideReplicateCount smallint output,
	@ORFCoverageComputationLevel tinyint output,
	@InternalStdInclusionMode tinyint output,

	@MinimumPeptideProphetProbability real output,
	@MaximumMatchesPerUMCToKeep smallint output
)
AS
	Set NoCount On

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Set @message = ''

	Declare @MDIDText varchar(19)
	Declare @DefaultID int
	Declare @InstrumentName varchar(255)
	Declare @InstrumentNameMatched varchar(255)
	Declare @DatasetName varchar(255)

	Declare @MDIDMinimumHighNormalizedScore real
	Declare @MDIDMinimumHighDiscriminant real
	Declare @MDIDMinimumPepProphet real
	Declare @MDIDMinimumPMTQS real

	Set @MDIDMinimumHighNormalizedScore = 0
	Set @MDIDMinimumHighDiscriminant = 0
	Set @MDIDMinimumPepProphet = 0
	Set @MDIDMinimumPMTQS = 0
	
	If @MDID Is Null
		Set @MDIDText = 'Null'
	Else
		Set @MDIDText = Convert(varchar(19), @MDID)
	
	-- Define the default values
	Set @Fraction_Highest_Abu_To_Use  = 0.33
	Set @Normalize_To_Standard_Abundances = 1
	Set @Standard_Abundance_Min = 0
	Set @Standard_Abundance_Max = 5000000000

	Set @UMCAbundanceMode = 0
	Set @Expression_Ratio_Mode = 0

	Set @MinimumHighNormalizedScore = 0
	Set @MinimumHighDiscriminantScore = 0
	Set @MinimumPeptideProphetProbability = 0
	Set @MinimumPMTQualityScore = 0
	
	Set @MinimumPeptideLength = 6
	Set @MaximumMatchesPerUMCToKeep = 1
	Set @MinimumMatchScore = 0.25
	Set @MinimumDelMatchScore = 0

	Set @MinimumPeptideReplicateCount = 0
	Set @ORFCoverageComputationLevel = 1
	Set @InternalStdInclusionMode = 0


	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try

		If Not @MDID Is Null
		Begin -- <a>
			Set @CurrentLocation = 'Lookup the instrument name and the dataset name for MDID ' + @MDIDText
			--
			SELECT TOP 1 @InstrumentName = FAD.Instrument, 
						 @DatasetName = FAD.Dataset,
						 @MDIDMinimumHighNormalizedScore = Minimum_High_Normalized_Score,
						 @MDIDMinimumHighDiscriminant = Minimum_High_Discriminant_Score,
						 @MDIDMinimumPepProphet = Minimum_Peptide_Prophet_Probability,
						 @MDIDMinimumPMTQS = Minimum_PMT_Quality_Score
			FROM T_Match_Making_Description MMD INNER JOIN
				T_FTICR_Analysis_Description FAD ON MMD.MD_Reference_Job = FAD.Job
			WHERE MMD.MD_ID = @MDID
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount

			If @myRowCount > 0
			Begin -- <b>
				-- Look for a matching entry in T_Quantitation_Defaults
				
				Set @DefaultID = 0

				-- First, try to match instrument and dataset
				-- Use the PATINDEX function to compare the dataset name filters defined in the table against @DatasetName
				SELECT TOP 1 @DefaultID = Default_ID, @InstrumentNameMatched = Instrument_Name
				FROM T_Quantitation_Defaults
				WHERE NOT Dataset_Name_Filter Is Null AND
					(Instrument_Name = @InstrumentName OR 
					Instrument_Name LIKE '%[%]%' AND PATINDEX(Instrument_Name, @InstrumentName) > 0) AND
					IsNull(PATINDEX(Dataset_Name_Filter, @DatasetName), 0) > 0
				ORDER BY Default_ID ASC
				--
				SELECT @myError = @@Error, @myRowCount = @@RowCount
			
				If @myRowCount > 0
					Set @message = Convert(varchar(12), @DefaultID) + ': Matched Instrument Name and Dataset Name: ' + @InstrumentNameMatched + ' and ' + @DatasetName
				Else
				Begin -- <c1>
					-- No match, so just match the instrument, excluding any rows with Dataset_Name_Filter defined
					SELECT TOP 1 @DefaultID = Default_ID, @InstrumentNameMatched = Instrument_Name
					FROM T_Quantitation_Defaults
					WHERE (Instrument_Name = @InstrumentName OR 
						Instrument_Name LIKE '%[%]%' AND PATINDEX(Instrument_Name, @InstrumentName) > 0) AND
						Len(IsNull(Dataset_Name_Filter, '')) = 0
					ORDER BY Default_ID ASC
					--
					SELECT @myError = @@Error, @myRowCount = @@RowCount

					If @myRowCount > 0
						Set @message = Convert(varchar(12), @DefaultID) + ': Matched Instrument Name: ' + @InstrumentNameMatched + ' but not ' + @DatasetName
					Else
					Begin -- <d>
						-- Still no match, look for the 'DefaultSettings' row
						SELECT TOP 1 @DefaultID = Default_ID
						FROM T_Quantitation_Defaults
						WHERE Instrument_Name = 'DefaultSettings'
						ORDER BY Default_ID ASC
						--
						SELECT @myError = @@Error, @myRowCount = @@RowCount

						If @myRowCount > 0
							Set @message = Convert(varchar(12), @DefaultID) + ': Matched DefaultSettings'
						Else
						Begin -- <e>
							-- Still no match, so post an error to the log and select the first row in the table
							Set @message = 'The DefaultSettings row is missing from table T_Quantitation_Defaults'
							execute PostLogEntry 'Error', @message, 'LookupQuantitationDefaults'

							SELECT TOP 1 @DefaultID = Default_ID
							FROM T_Quantitation_Defaults
							ORDER BY Default_ID ASC
							--
							SELECT @myError = @@Error, @myRowCount = @@RowCount
						End -- </e>
					End -- </d>
				End -- </c1>
				
				If @DefaultID > 0
				Begin -- <c2>
					Set @CurrentLocation = 'Retrieve default settings from T_Quantitation_Defaults for Default_ID ' + Convert(varchar(12), @DefaultID)
					--
					SELECT	@Fraction_Highest_Abu_To_Use = Fraction_Highest_Abu_To_Use, 
							@Normalize_To_Standard_Abundances = Normalize_To_Standard_Abundances, 
							@Standard_Abundance_Min = Standard_Abundance_Min, 
							@Standard_Abundance_Max = Standard_Abundance_Max, 
							@UMCAbundanceMode = UMC_Abundance_Mode, 
							@Expression_Ratio_Mode = Expression_Ratio_Mode, 
							@MinimumHighNormalizedScore = Minimum_High_Normalized_Score, 
							@MinimumHighDiscriminantScore = Minimum_High_Discriminant_Score, 
							@MinimumPeptideProphetProbability = Minimum_Peptide_Prophet_Probability,
							@MinimumPMTQualityScore = Minimum_PMT_Quality_Score, 
							@MinimumPeptideLength = Minimum_Peptide_Length, 
							@MaximumMatchesPerUMCToKeep = Maximum_Matches_per_UMC_to_Keep,
							@MinimumMatchScore = Minimum_Match_Score, 
							@MinimumDelMatchScore = Minimum_Del_Match_Score, 
							@MinimumPeptideReplicateCount = Minimum_Peptide_Replicate_Count, 
							@ORFCoverageComputationLevel = ORF_Coverage_Computation_Level, 
							@InternalStdInclusionMode = Internal_Std_Inclusion_Mode
					FROM T_Quantitation_Defaults
					WHERE Default_ID = @DefaultID
					--
					SELECT @myError = @@Error, @myRowCount = @@RowCount

				End -- </c2>
				
				Set @CurrentLocation = 'Possibly increase the minimum score values to those defined in the MDID'
				--
				If @MDIDMinimumHighNormalizedScore > IsNull(@MinimumHighNormalizedScore,0)
					Set @MinimumHighNormalizedScore = @MDIDMinimumHighNormalizedScore

				If @MDIDMinimumHighDiscriminant > IsNull(@MinimumHighDiscriminantScore,0)
					Set @MinimumHighDiscriminantScore = @MDIDMinimumHighDiscriminant

				If @MDIDMinimumPepProphet > IsNull(@MinimumPeptideProphetProbability,0)
					Set @MinimumPeptideProphetProbability = @MDIDMinimumPepProphet

				If @MDIDMinimumPMTQS > IsNull(@MinimumPMTQualityScore,0)
					Set @MinimumPMTQualityScore = @MDIDMinimumPMTQS

			End -- </b>
		End -- </a>
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'LookupQuantitationDefaults')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1,
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch
				
Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[LookupQuantitationDefaults] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[LookupQuantitationDefaults] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[LookupQuantitationDefaults] TO [MTS_DB_Lite] AS [dbo]
GO
