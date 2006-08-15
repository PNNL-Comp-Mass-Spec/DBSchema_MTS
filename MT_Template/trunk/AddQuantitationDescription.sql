/****** Object:  StoredProcedure [dbo].[AddQuantitationDescription] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.AddQuantitationDescription
/****************************************************	
**
**  Desc: Adds row to the T_Quantitation_Description table
**        If MDID is supplied, then also makes an entry in T_Quantitation_MDIDs
**
**  Return values: 0 if success, otherwise, error code
**
**  Parameters: see comments beside each parameter
**
**  Auth: mem
**	Date: 06/03/2003
**
**  Updated: 7/31/2003 by mem
**			 8/26/2003 - changed Trial to Replicate where appropriate 
**						 Now looks for old QuantitationID tasks with identical sample name and identical comment or identical MDID
**						 If found, changes those the Quantitation_State for the old tasks to 5 = Superseded
**			 9/17/2003 - Added @AddBackExcludedMassTags and @Expression_Ratio_Mode parameters
**			 11/18/2003 - Added @MinimumHighNormalizedScore
**			 12/01/2003 - Added @MinimumPeptideReplicateCount, @RepNormalizationPctSmallDataToDiscard, @RepNormalizationPctLargeDataToDiscard, and @RepNormalizationMinimumDataPointCount
**			 04/13/2004 - Added @UMCAbundanceMode, @MinimumPMTQualityScore, @MinimumPeptideLength, @ORFCoverageComputationLevel
**			 02/05/2005 - Added @MinimumHighDiscriminantScore
**			 04/05/2005 - Added @MinimumMatchScore (aka SLiC Score)
**						- Switched from using @@Identity to SCOPE_IDENTITY()
**						- Changed default value for @MinimumHighDiscriminantScore to 0.2 and for @MinimumMatchScore to 0.35
**			 04/07/2005 - Added MinimumDelMatchScore (aka Del SLiC Score)
**			 06/16/2005 - Added InternalStdInclusionMode
**			 08/12/2005 - Removed all of the processing option parameters and switched to calling LookupQuantitationDefaults to obtain the default values from T_Quantitation_Defaults.
**						- Removed parameter @IniFileName
**			 09/22/2005 - Added parameter @LookupDefaultOptions to specify whether the processing option parameters should be used or whether the values in T_Quantitation_Defaults should be used
**						- Added back the processing option parameters since they are needed by Q Rollup
**
****************************************************/
(
	@SampleName varchar(255),					-- Sample name can be anything, but is required

	@MDID int = Null,							-- Reference to T_Match_Making_Description table, 
												--  leave null to just make an entry in T_Quantitation_Description and not in T_Quantitation_MDIDs
	@Replicate smallint = 1,					-- Entered into T_Quantitation_MDIDs if MDID is not null
	@Fraction smallint = 1,						-- Entered into T_Quantitation_MDIDs if MDID is not null
	@TopLevelFraction smallint = 1,				-- Entered into T_Quantitation_MDIDs if MDID is not null

	@Comment varchar(255) = '',					-- Sample comment; optional, default value is a blank comment
	
	@ProcessImmediately tinyint = 0,			-- Automatically call QuantitationProcessStart
				
	@Quantitation_ID int=Null Output,			-- ID of the newly added row in T_Quantitation_Description
	@Q_MDID_ID int=Null Output,					-- ID of the newly added row in T_Quantitation_MDIDs
	
	@EntriesProcessedReturn int=0 Output,		-- If @QuantitationProcessStart = 1, then returns number of entries processed by QuantitationProcessStart

	@LookupDefaultOptions tinyint = 1,			-- If 1, then uses options in T_Quantitation_Defaults

	@Fraction_Highest_Abu_To_Use real = 0.33,		-- Ignored if @LookupDefaultOptions <> 0
	@Normalize_To_Standard_Abundances tinyint = 1,	-- Ignored if @LookupDefaultOptions <> 0
	@Standard_Abundance_Min float = 0,				-- Ignored if @LookupDefaultOptions <> 0
	@Standard_Abundance_Max float = 5000000000,		-- Ignored if @LookupDefaultOptions <> 0

	@UMCAbundanceMode tinyint = 0,					-- Ignored if @LookupDefaultOptions <> 0
	@Expression_Ratio_Mode tinyint = 0,				-- Ignored if @LookupDefaultOptions <> 0

	@MinimumHighNormalizedScore real = 0,			-- Ignored if @LookupDefaultOptions <> 0
	@MinimumHighDiscriminantScore real = 0.2,		-- Ignored if @LookupDefaultOptions <> 0
	@MinimumPMTQualityScore real = 0,				-- Ignored if @LookupDefaultOptions <> 0
	
	@MinimumPeptideLength tinyint = 6,				-- Ignored if @LookupDefaultOptions <> 0
	@MinimumMatchScore real = 0.35,					-- Ignored if @LookupDefaultOptions <> 0
	@MinimumDelMatchScore real = 0.1,				-- Ignored if @LookupDefaultOptions <> 0

	@MinimumPeptideReplicateCount smallint = 0,		-- Ignored if @LookupDefaultOptions <> 0
	@ORFCoverageComputationLevel tinyint = 1,		-- Ignored if @LookupDefaultOptions <> 0
	@InternalStdInclusionMode tinyint = 0			-- Ignored if @LookupDefaultOptions <> 0
)
As
	Set NoCount On

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Declare @MatchCount int
	Set @MatchCount = 0
		
	Declare @message varchar(255)
	Set @message = ''
		
	Declare @State tinyint
	Set @State=1					-- new record state is always New

	Declare @LocalEntriesProcessed int
	Set @LocalEntriesProcessed=0

	If IsNull(@LookupDefaultOptions, 1) <> 0
		-- Lookup the Quantitation Defaults for @MDID (even if it's null)
		Exec LookupQuantitationDefaults @MDID, @message output,
										@Fraction_Highest_Abu_To_Use output, @Normalize_To_Standard_Abundances output, 
										@Standard_Abundance_Min output, @Standard_Abundance_Max output, @UMCAbundanceMode output, 
										@Expression_Ratio_Mode output, @MinimumHighNormalizedScore output, 
										@MinimumHighDiscriminantScore output, @MinimumPMTQualityScore output, 
										@MinimumPeptideLength output, @MinimumMatchScore output, @MinimumDelMatchScore output, 
										@MinimumPeptideReplicateCount output, @ORFCoverageComputationLevel output, 
										@InternalStdInclusionMode output
			

	
	Begin Transaction TransAddQuantitationDescription

	-- Look for existing QuantitationID tasks with the same SampleName and Comment or with the same MDID
	-- If found, and if their MDID entries have MD_State = 5, then set Quantitation_State = 5
	-- Do not change Quantitation_State if MD_State is not 5, since we want to allow the option to
	--  rollup the same MD_ID value with different quantitation options
	UPDATE T_Quantitation_Description
	SET Quantitation_State = 5
	WHERE (Quantitation_ID IN
	        (	SELECT	QD.Quantitation_ID
				FROM	T_Quantitation_Description AS QD INNER JOIN
						T_Quantitation_MDIDs ON 
						QD.Quantitation_ID = T_Quantitation_MDIDs.Quantitation_ID
							INNER JOIN
						T_Match_Making_Description AS MMD ON 
						T_Quantitation_MDIDs.MD_ID = MMD.MD_ID
				WHERE	QD.Quantitation_State <> 5 AND
						MMD.MD_State = 5 AND 
						(	(QD.SampleName = @SampleName AND QD.Comment = @Comment) 
							OR
							T_Quantitation_MDIDs.MD_ID = @MDID
						)
			)
		  )
	--
	Select @myError = @@Error, @myRowCount = @@RowCount
	--
	If @myError <> 0
	Begin
		RollBack Transaction TransAddQuantitationDescription
		Set @myError = 101
		Set @message = 'Error checking for similar Quantitation tasks'
		Goto Done
	End
	
	
	-- Add a new row to the T_Quantitation_Description table
	INSERT INTO dbo.T_Quantitation_Description
		 (	SampleName, Quantitation_State, Comment, 
			Fraction_Highest_Abu_To_Use, Normalize_To_Standard_Abundances,
			Standard_Abundance_Min, Standard_Abundance_Max, 
			UMC_Abundance_Mode,
			Expression_Ratio_Mode,
			Minimum_MT_High_Normalized_Score,
			Minimum_MT_High_Discriminant_Score,
			Minimum_PMT_Quality_Score,
			Minimum_Peptide_Length,
			Minimum_Match_Score,
			Minimum_Del_Match_Score,
			Minimum_Peptide_Replicate_Count,
			ORF_Coverage_Computation_Level,
			Internal_Std_Inclusion_Mode
		 )
	VALUES (@SampleName, @State, @Comment,
			Round(@Fraction_Highest_Abu_To_Use, 4), @Normalize_To_Standard_Abundances,
			@Standard_Abundance_Min, @Standard_Abundance_Max, 
			@UMCAbundanceMode,
			@Expression_Ratio_Mode,
			@MinimumHighNormalizedScore,
			@MinimumHighDiscriminantScore,
			@MinimumPMTQualityScore,
			@MinimumPeptideLength,
			@MinimumMatchScore,
			@MinimumDelMatchScore,
			@MinimumPeptideReplicateCount,
			@ORFCoverageComputationLevel,
			@InternalStdInclusionMode
			)
	--
	Select @myError = @@Error, @myRowCount = @@RowCount
	--
	If @myError <> 0 Or @myRowCount <> 1
	Begin
		RollBack Transaction TransAddQuantitationDescription
		Set @myError = 102
		Set @message = 'Error adding row to T_Quantitation_Description'
		Goto Done
	End
	--
	Set @Quantitation_ID = SCOPE_IDENTITY()		--return ID

	-- Now add a new row to T_Quantitation_MDIDs (if @MDID is not Null)
	If @MDID Is Not Null
	Begin
		INSERT INTO dbo.T_Quantitation_MDIDs
			(Quantitation_ID, MD_ID, [Replicate], Fraction, TopLevelFraction)
		VALUES (@Quantitation_ID, @MDID, @Replicate, @Fraction, @TopLevelFraction)
		--
		Select @myError = @@Error, @myRowCount = @@RowCount
		--
		If @myError <> 0 Or @myRowCount <> 1
		Begin
			RollBack Transaction TransAddQuantitationDescription
			Set @myError = 103
			Set @message = 'Error adding row to T_Quantitation_MDIDs'
			Set @Quantitation_ID = Null
			Goto Done

		End
		--
		Set @Q_MDID_ID = SCOPE_IDENTITY()		--return ID
		
	End

	If @myError = 0
		Begin
			Commit Transaction TransAddQuantitationDescription
			
			If @ProcessImmediately = 1
			Begin
				Exec QuantitationProcessStart @EntriesProcessed = @LocalEntriesProcessed Output
				Set @EntriesProcessedReturn = @LocalEntriesProcessed
			End
		End
	Else
		Begin
			RollBack Transaction TransAddQuantitationDescription
			Set @myError = 104
			Set @message = 'Unknown error'
			Set @Quantitation_ID = Null
			Set @Q_MDID_ID = Null
		End
	
Done:
	Select @message
	
	Return @myError


GO
GRANT EXECUTE ON [dbo].[AddQuantitationDescription] TO [DMS_SP_User]
GO
