SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[AddUpdateQuantitationDescription]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[AddUpdateQuantitationDescription]
GO

CREATE PROCEDURE dbo.AddUpdateQuantitationDescription
/****************************************************	
**  Desc: Adds or updates a Q Rollup report definition
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: 
**
**  Auth:	jee
**	Date:	07/01/2004
**			04/07/2005 mem - Added parameters @MinimumMTHighDiscriminantScore, @MinimumMatchScore, and @MinimumDelMatchScore
**			11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**
****************************************************/
(
	@MTDBName varchar(128) = '',
	@SampleName varchar(255),					-- Sample name can be anything, but is required

	@MDIDList varchar(1024),					-- List of references to T_Match_Making_Description table, 
	@ReplicateList varchar(256),				-- Entered into T_Quantitation_MDIDs
	@FractionList varchar(256),					-- Entered into T_Quantitation_MDIDs
	@TopLevelFractionList varchar(256),			-- Entered into T_Quantitation_MDIDs

	@Comment varchar(255) = '',					-- Sample comment; optional, default value is a blank comment
	
	@Quantitation_ID int Output,			--ID of the newly added row in T_Quantitation_Description
	@Q_MDID_IDList varchar(1024) Output,	--ID of the newly added row in T_Quantitation_MDIDs
	
	@Fraction_Highest_Abu_To_Use decimal(9,8) = 0.33,	-- Quantitation parameter; used by QuantitationProcessWork
	@Normalize_To_Standard_Abundances tinyint = 1,		-- Quantitation parameter; used by QuantitationProcessWork
	@Standard_Abundance_Min float = 0,					-- Quantitation parameter; used by QuantitationProcessWork
	@Standard_Abundance_Max float = 5000000000,			-- Quantitation parameter; used by QuantitationProcessWork
	@Minimum_Criteria_ORFMassDaDivisor int = 15000,		-- Quantitation parameter; used by QuantitationProcessWork
	@Minimum_Criteria_UniqueMTCountMinimum int = 2,		-- Quantitation parameter; used by QuantitationProcessWork
	@Minimum_Criteria_MTIonMatchCountMinimum int = 6,	-- Quantitation parameter; used by QuantitationProcessWork
	@Minimum_Criteria_FractionScansMatchingSingleMassTagMinimum decimal(9,8) = 0.50,		-- Quantitation parameter; used by QuantitationProcessWork

	@RemoveOutlierAbundancesForReplicates tinyint = 1,		-- Quantitation parameter; used by QuantitationProcessWork
	@FractionCrossReplicateAvgInRange decimal(9,5) = 0.8,	-- Quantitation parameter; used by QuantitationProcessWork
				
	@AddBackExcludedMassTags tinyint = 0,
	@Expression_Ratio_Mode tinyint = 0,
	@MinimumMTHighNormalizedScore decimal(9,5) = 0,
	@MinimumPeptideReplicateCount smallint = 0, 
	@RepNormalizationPctSmallDataToDiscard tinyint = 10, 
	@RepNormalizationPctLargeDataToDiscard tinyint = 5, 
	@RepNormalizationMinimumDataPointCount smallint = 10,
	@UMCAbundanceMode tinyint = 0,
	@MinimumPMTQualityScore decimal(9,5) = 0,
	@MinimumPeptideLength tinyint = 6,
	@ORFCoverageComputationLevel tinyint = 1,
	@MinimumMTHighDiscriminantScore real = 0.2,
	@MinimumMatchScore real = 0.35,
	@MinimumDelMatchScore real = 0.1
)
AS
	SET NOCOUNT ON
	
	declare @result int
	declare @stmt nvarchar(300)
	declare @params nvarchar(300)

	set @stmt = N'exec [' + @MTDBName + N'].dbo.AddUpdateQuantitationDescription '
	set @stmt = @stmt + N'@SampleName, @MDIDList, @ReplicateList, '
	set @stmt = @stmt + N'@FractionList, @TopLevelFractionList, @Comment, '
	set @stmt = @stmt + N'@Quantitation_ID, @Q_MDID_IDList, '
	set @stmt = @stmt + N'@Fraction_Highest_Abu_To_Use, @Normalize_To_Standard_Abundances, '
	set @stmt = @stmt + N'@Standard_Abundance_Min, @Standard_Abundance_Max, '
	set @stmt = @stmt + N'@Minimum_Criteria_ORFMassDaDivisor, @Minimum_Criteria_UniqueMTCountMinimum, '
	set @stmt = @stmt + N'@Minimum_Criteria_MTIonMatchCountMinimum, '
	set @stmt = @stmt + N'@Minimum_Criteria_FractionScansMatchingSingleMassTagMinimum, '
	set @stmt = @stmt + N'@RemoveOutlierAbundancesForReplicates, @FractionCrossReplicateAvgInRange, '
	set @stmt = @stmt + N'@AddBackExcludedMassTags, @Expression_Ratio_Mode, '
	set @stmt = @stmt + N'@MinimumMTHighNormalizedScore, @MinimumPeptideReplicateCount, '
	set @stmt = @stmt + N'@RepNormalizationPctSmallDataToDiscard, @RepNormalizationPctLargeDataToDiscard, '
	set @stmt = @stmt + N'@RepNormalizationMinimumDataPointCount, @UMCAbundanceMode, '
	set @stmt = @stmt + N'@MinimumPMTQualityScore, @MinimumPeptideLength, '
	set @stmt = @stmt + N'@ORFCoverageComputationLevel, @MinimumMTHighDiscriminantScore, '
	set @stmt = @stmt + N'@MinimumMatchScore, @MinimumDelMatchScore'

	set @params = N'@SampleName varchar(255), @MDIDList varchar(1024), @ReplicateList varchar(256), '
	set @params = @params + N'@FractionList varchar(256), @TopLevelFractionList varchar(256), @Comment varchar(255), '
	set @params = @params + N'@Quantitation_ID int Output, @Q_MDID_IDList varchar(1024) Output, '
	set @params = @params + N'@Fraction_Highest_Abu_To_Use decimal(9,8), @Normalize_To_Standard_Abundances tinyint, '
	set @params = @params + N'@Standard_Abundance_Min float, @Standard_Abundance_Max float, '
	set @params = @params + N'@Minimum_Criteria_ORFMassDaDivisor int, @Minimum_Criteria_UniqueMTCountMinimum int, '
	set @params = @params + N'@Minimum_Criteria_MTIonMatchCountMinimum int, '
	set @params = @params + N'@Minimum_Criteria_FractionScansMatchingSingleMassTagMinimum decimal(9,8), '
	set @params = @params + N'@RemoveOutlierAbundancesForReplicates tinyint, @FractionCrossReplicateAvgInRange decimal(9,5), '
	set @params = @params + N'@AddBackExcludedMassTags tinyint, @Expression_Ratio_Mode tinyint, '
	set @params = @params + N'@MinimumMTHighNormalizedScore decimal(9,5), @MinimumPeptideReplicateCount smallint, '
	set @params = @params + N'@RepNormalizationPctSmallDataToDiscard tinyint, @RepNormalizationPctLargeDataToDiscard tinyint, '
	set @params = @params + N'@RepNormalizationMinimumDataPointCount smallint, @UMCAbundanceMode tinyint, '
	set @params = @params + N'@MinimumPMTQualityScore decimal(9,5), @MinimumPeptideLength tinyint, '
	set @params = @params + N'@ORFCoverageComputationLevel tinyint, '
	set @params = @params + N'@MinimumMTHighDiscriminantScore real, '
	set @params = @params + N'@MinimumMatchScore real, '
	set @params = @params + N'@MinimumDelMatchScore real'


	exec @result = sp_executesql @stmt, @params, @SampleName = @SampleName, @MDIDList = @MDIDList, 
			@ReplicateList = @ReplicateList, @FractionList = @FractionList, @TopLevelFractionList = @TopLevelFractionList, 
			@Comment = @Comment, @Quantitation_ID = @Quantitation_ID, @Q_MDID_IDList = @Q_MDID_IDList, 
			@Fraction_Highest_Abu_To_Use = @Fraction_Highest_Abu_To_Use, 
			@Normalize_To_Standard_Abundances = @Normalize_To_Standard_Abundances, 
			@Standard_Abundance_Min = @Standard_Abundance_Min, @Standard_Abundance_Max = @Standard_Abundance_Max, 
			@Minimum_Criteria_ORFMassDaDivisor = @Minimum_Criteria_ORFMassDaDivisor, 
			@Minimum_Criteria_UniqueMTCountMinimum = @Minimum_Criteria_UniqueMTCountMinimum, 
			@Minimum_Criteria_MTIonMatchCountMinimum = @Minimum_Criteria_MTIonMatchCountMinimum, 
			@Minimum_Criteria_FractionScansMatchingSingleMassTagMinimum = @Minimum_Criteria_FractionScansMatchingSingleMassTagMinimum, 
			@RemoveOutlierAbundancesForReplicates = @RemoveOutlierAbundancesForReplicates, 
			@FractionCrossReplicateAvgInRange = @FractionCrossReplicateAvgInRange, 
			@AddBackExcludedMassTags = @AddBackExcludedMassTags, 
			@Expression_Ratio_Mode = @Expression_Ratio_Mode, @MinimumMTHighNormalizedScore = @MinimumMTHighNormalizedScore, 
			@MinimumPeptideReplicateCount = @MinimumPeptideReplicateCount, 
			@RepNormalizationPctSmallDataToDiscard = @RepNormalizationPctSmallDataToDiscard, 
			@RepNormalizationPctLargeDataToDiscard = @RepNormalizationPctLargeDataToDiscard, 
			@RepNormalizationMinimumDataPointCount = @RepNormalizationMinimumDataPointCount, 
			@UMCAbundanceMode = @UMCAbundanceMode, @MinimumPMTQualityScore = @MinimumPMTQualityScore, 
			@MinimumPeptideLength = @MinimumPeptideLength, @ORFCoverageComputationLevel  = @ORFCoverageComputationLevel,
			@MinimumMTHighDiscriminantScore = @MinimumMTHighDiscriminantScore, 
			@MinimumMatchScore = @MinimumMatchScore, @MinimumDelMatchScore = @MinimumDelMatchScore

	RETURN @result

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[AddUpdateQuantitationDescription]  TO [DMS_SP_User]
GO

