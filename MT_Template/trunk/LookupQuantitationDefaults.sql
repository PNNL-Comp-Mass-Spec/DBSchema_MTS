/****** Object:  StoredProcedure [dbo].[LookupQuantitationDefaults] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE dbo.LookupQuantitationDefaults
/****************************************************	
**
**  Desc: Looks up the default values to use for Q Rollup given the MDID value
**
**  Return values: 0 if success, otherwise, error code
**
**  Auth:	mem
**	Date:	08/12/2005
**
****************************************************/
(
	@MDID int,
	@message varchar(255) = '' output,
	
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
	@InternalStdInclusionMode tinyint output
)
AS
	Set NoCount On

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Set @message = ''

	Declare @MDIDText varchar(12)
	Declare @DefaultID int
	Declare @InstrumentName varchar(255)
	Declare @DatasetName varchar(255)
	
	If @MDID Is Null
		Set @MDIDText = 'Null'
	Else
		Set @MDIDText = Convert(varchar(12), @MDID)
	
	-- Define the default values
	Set @Fraction_Highest_Abu_To_Use  = 0.33
	Set @Normalize_To_Standard_Abundances = 1
	Set @Standard_Abundance_Min = 0
	Set @Standard_Abundance_Max = 5000000000

	Set @UMCAbundanceMode = 0
	Set @Expression_Ratio_Mode = 0

	Set @MinimumHighNormalizedScore = 0
	Set @MinimumHighDiscriminantScore = 0.2
	Set @MinimumPMTQualityScore = 0
	Set @MinimumPeptideLength = 6
	Set @MinimumMatchScore = 0.35
	Set @MinimumDelMatchScore = 0.1

	Set @MinimumPeptideReplicateCount = 0
	Set @ORFCoverageComputationLevel = 1
	Set @InternalStdInclusionMode = 0
	
	If Not @MDID Is Null
	Begin

		-- Lookup the instrument name and the dataset name for @MDID
		SELECT TOP 1 @InstrumentName = FAD.Instrument, @DatasetName = FAD.Dataset
		FROM T_Match_Making_Description MMD INNER JOIN
			 T_FTICR_Analysis_Description FAD ON MMD.MD_Reference_Job = FAD.Job
		WHERE MMD.MD_ID = @MDID
		--
		SELECT @myError = @@Error, @myRowCount = @@RowCount

		If @myError <> 0
		Begin
			Set @myError = 30000
			Set @message = 'Error looking up instrument and dataset for MDID ' + @MDIDText
			Goto Done
		End


		If @myRowCount = 1
		Begin
			-- Look for a matching entry in T_Quantitation_Defaults
			
			Set @DefaultID = 0

			-- First, try to match instrument and dataset
			-- Use the PATINDEX function to compare the dataset name filters defined in the table against @DatasetName
			SELECT TOP 1 @DefaultID = Default_ID
			FROM T_Quantitation_Defaults
			WHERE NOT Dataset_Name_Filter Is Null AND
				  Instrument_Name = @InstrumentName AND
				  IsNull(PATINDEX(Dataset_Name_Filter, @DatasetName), 0) > 0
			ORDER BY Default_ID ASC
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount
		
			If @myRowCount > 0
				Set @message = Convert(varchar(12), @DefaultID) + ': Matched Instrument Name and Dataset Name: ' + @InstrumentName + ' and ' + @DatasetName
			Else
			Begin
				-- No match, so just match the instrument, excluding any rows with Dataset_Name_Filter defined
				SELECT TOP 1 @DefaultID = Default_ID
				FROM T_Quantitation_Defaults
				WHERE Instrument_Name = @InstrumentName AND
					  Len(IsNull(Dataset_Name_Filter, '')) = 0
				ORDER BY Default_ID ASC
				--
				SELECT @myError = @@Error, @myRowCount = @@RowCount

				If @myRowCount > 0
					Set @message = Convert(varchar(12), @DefaultID) + ': Matched Instrument Name: ' + @InstrumentName + ' but not ' + @DatasetName
				Else
				Begin
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
					Begin
						-- Still no match, so post an error to the log and select the first row in the table
						Set @message = 'The DefaultSettings row is missing from table T_Quantitation_Defaults'
						execute PostLogEntry 'Error', @message, 'LookupQuantitationDefaults'

						SELECT TOP 1 @DefaultID = Default_ID
						FROM T_Quantitation_Defaults
						ORDER BY Default_ID ASC
						--
						SELECT @myError = @@Error, @myRowCount = @@RowCount
					End
				End
			End
			
			If @DefaultID > 0
			Begin
				SELECT	@Fraction_Highest_Abu_To_Use = Fraction_Highest_Abu_To_Use, 
						@Normalize_To_Standard_Abundances = Normalize_To_Standard_Abundances, 
						@Standard_Abundance_Min = Standard_Abundance_Min, 
						@Standard_Abundance_Max = Standard_Abundance_Max, 
						@UMCAbundanceMode = UMC_Abundance_Mode, 
						@Expression_Ratio_Mode = Expression_Ratio_Mode, 
						@MinimumHighNormalizedScore = Minimum_High_Normalized_Score, 
						@MinimumHighDiscriminantScore = Minimum_High_Discriminant_Score, 
						@MinimumPMTQualityScore = Minimum_PMT_Quality_Score, 
						@MinimumPeptideLength = Minimum_Peptide_Length, 
						@MinimumMatchScore = Minimum_Match_Score, 
						@MinimumDelMatchScore = Minimum_Del_Match_Score, 
						@MinimumPeptideReplicateCount = Minimum_Peptide_Replicate_Count, 
						@ORFCoverageComputationLevel = ORF_Coverage_Computation_Level, 
						@InternalStdInclusionMode = Internal_Std_Inclusion_Mode
				FROM T_Quantitation_Defaults
				WHERE Default_ID = @DefaultID
				--
				SELECT @myError = @@Error, @myRowCount = @@RowCount

				If @myError <> 0
				Begin
					Set @myError = 30001
					Set @message = 'Error retrieving default settings from T_Quantitation_Defaults for MDID ' + @MDIDText
					Goto Done
				End
			End
		End
	End
						
Done:
	Return @myError



GO
GRANT EXECUTE ON [dbo].[LookupQuantitationDefaults] TO [DMS_SP_User]
GO
