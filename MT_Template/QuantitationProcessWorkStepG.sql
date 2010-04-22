/****** Object:  StoredProcedure [dbo].[QuantitationProcessWorkStepG] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.QuantitationProcessWorkStepG
/****************************************************	
**  Desc: 
**
**  Return values: 0 if success, otherwise, error code
**
**  Auth:	mem
**	Date:	09/07/2006
**
****************************************************/
(
	@MinimumPotentialPMTQualityScore real,
	@message varchar(512)='' output
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

 	Declare @LastRefID int,
 			@ProteinCoverageResidueCount int,
 			@ProteinCoverageResidueCountHighAbu int,
			@PotentialProteinCoverageResidueCount int,
 			@PotentialProteinCoverageFraction float,
 			@ProteinSequenceLength int,
 			@ProteinProcessingDone tinyint,
 			@Protein_Sequence varchar(8000),
 			@Protein_Sequence_HighAbu varchar(8000),
 			@Protein_Sequence_Full varchar(8000)

	-----------------------------------------------------------
	-- Step 13
	--
	-- Compute Protein Coverage
	-----------------------------------------------------------

	if exists (select * from dbo.sysobjects where id = object_id(N'[#Protein_Coverage]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table [#Protein_Coverage]

	CREATE TABLE #Protein_Coverage (
		[Ref_ID] int NOT NULL ,
		[Protein_Sequence] varchar(8000) NOT NULL, 				-- Used to compute protein coverage
		[Protein_Coverage_Residue_Count] int NULL,
		[Protein_Coverage_Fraction] real NULL,
		[Protein_Coverage_Fraction_High_Abundance] real NULL,
		[Potential_Protein_Coverage_Residue_Count] int NULL,
		[Potential_Protein_Coverage_Fraction] real NULL
	) ON [PRIMARY]

	CREATE UNIQUE CLUSTERED INDEX #IX__TempTable__ProteinCoverage_Ref_ID ON #Protein_Coverage([Ref_ID]) ON [PRIMARY]

	-- Populate the #Protein_Coverage table
	-- We have to use a table separate from #UMCMatchResultsSummary for computing Protein coverage
	--  since Sql Server sets a maximum record length of 8060 bytes
	-- Note that proteins with sequences longer than 8000 residues will get truncated
	
	INSERT INTO #Protein_Coverage
		(Ref_ID, Protein_Sequence)
	SELECT #UMCMatchResultsSummary.Ref_ID,
			LOWER(Convert(varchar(8000), T_Proteins.Protein_Sequence))				-- Convert the protein sequence to lowercase
	FROM #UMCMatchResultsSummary INNER JOIN
			T_Proteins ON #UMCMatchResultsSummary.Ref_ID = T_Proteins.Ref_ID
	WHERE NOT T_Proteins.Protein_Sequence IS NULL
	GROUP BY #UMCMatchResultsSummary.Ref_ID, LOWER(Convert(varchar(8000), T_Proteins.Protein_Sequence))
	ORDER BY #UMCMatchResultsSummary.Ref_ID
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0 
	Begin
		Set @message = 'Error while populating the #Protein_Coverage temporary table'
		Set @myError = 138
		Goto Done
	End

/*		-- See if the master..xp_regex_replace procedure exists
	-- If it does, then we can use it to determine the number of capital letters in a string
 	Declare @RegExSPExists int,
	Set @RegExSPExists = 0
	SELECT @RegExSPExists = COUNT(*)
	FROM master..sysobjects
	WHERE name = 'xp_regex_replace'
	
	-- Make sure the user has permission to run xp_regex_replace
	If @RegExSPExists > 0
	Begin
		Set @Protein_Sequence_Full = 'massTAGdataBASE'
		EXEC master..xp_regex_replace @Protein_Sequence_Full, '[^A-Z]', '', @Protein_Sequence_Full OUTPUT
		If @Protein_Sequence_Full <> 'TAGBASE'
			Set @RegExSPExists = 0
	End
*/
	
	-- Process each Protein in #Protein_Coverage
	-- First determine the minimum Ref_ID value
	SET @LastRefID = -1
	SET @ProteinProcessingDone = 0
	--
	SELECT @LastRefID = MIN(Ref_ID)
	FROM #Protein_Coverage
	--
	SET @LastRefID = @LastRefID - 1
	
	-- Now step through the table
	WHILE @ProteinProcessingDone = 0
	Begin
		SELECT TOP 1 @LastRefID = Ref_ID,
						@Protein_Sequence_Full = Protein_Sequence
		FROM #Protein_Coverage
		WHERE Ref_ID > @LastRefID
		--	
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error while obtaining the next Ref_ID from the #Protein_Coverage temporary table'
			Set @myError = 139
			Goto Done
		End
		
		IF @myRowCount <> 1
			Set @ProteinProcessingDone = 1
		Else
		Begin
			Set @ProteinSequenceLength = Len(@Protein_Sequence_Full)
			If @ProteinSequenceLength > 0
			Begin
				--
				-- Step 13a - First compute the observed Protein coverage
				--
				Set @Protein_Sequence = @Protein_Sequence_Full
				SELECT @Protein_Sequence = REPLACE (@Protein_Sequence, T_Mass_Tags.Peptide, UPPER(T_Mass_Tags.Peptide))
				FROM #UMCMatchResultsSummary INNER JOIN
					T_Mass_Tags ON #UMCMatchResultsSummary.Mass_Tag_ID = T_Mass_Tags.Mass_Tag_ID
				WHERE #UMCMatchResultsSummary.Ref_ID = @LastRefID
				--	
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				If @myError <> 0 
				Begin
					Set @message = 'Error while capitalizing the protein sequence for Protein_Coverage use'
					Set @myError = 140
					Goto Done
				End

				Set @ProteinCoverageResidueCount = 0
				
/*					If @RegExSPExists > 0
				Begin
					-- Replace all the non-capital letters in @Protein_Sequence with blanks using a regular expression
					-- This SP is part of the xp_regex.dll file, written by Dan Farino 
					-- and obtained from http://www.codeproject.com/managedcpp/xpregex.asp
					EXEC master..xp_regex_replace @Protein_Sequence, '[^A-Z]', '', @Protein_Sequence OUTPUT
					Set @ProteinCoverageResidueCount = Len(@Protein_Sequence)
				End
				Else
				Begin
					exec CountCapitalLetters @Protein_Sequence, @CapitalLetterCount = @ProteinCoverageResidueCount OUTPUT
				End
*/
				exec CountCapitalLetters @Protein_Sequence, @CapitalLetterCount = @ProteinCoverageResidueCount OUTPUT

				--
				-- Step 13b - Compute the observed Protein coverage using only the high abundance peptides
				--
				Set @Protein_Sequence = @Protein_Sequence_Full
				SELECT @Protein_Sequence = REPLACE (@Protein_Sequence, T_Mass_Tags.Peptide, UPPER(T_Mass_Tags.Peptide))
				FROM #UMCMatchResultsSummary INNER JOIN
					T_Mass_Tags ON #UMCMatchResultsSummary.Mass_Tag_ID = T_Mass_Tags.Mass_Tag_ID
				WHERE #UMCMatchResultsSummary.Ref_ID = @LastRefID AND 
						#UMCMatchResultsSummary.Used_For_Abundance_Computation = 1
				--	
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				If @myError <> 0 
				Begin
					Set @message = 'Error while capitalizing the protein sequence for Protein_Coverage use'
					Set @myError = 141
					Goto Done
				End

				Set @ProteinCoverageResidueCountHighAbu = 0
				
/*				If @RegExSPExists > 0
				Begin
					-- Replace all the non-capital letters in @Protein_Sequence with blanks using a regular expression
					-- This SP is part of the xp_regex.dll file, written by Dan Farino 
					-- and obtained from http://www.codeproject.com/managedcpp/xpregex.asp
					EXEC master..xp_regex_replace @Protein_Sequence, '[^A-Z]', '', @Protein_Sequence OUTPUT
					Set @ProteinCoverageResidueCountHighAbu = Len(@Protein_Sequence)
				End
				Else
				Begin
					exec CountCapitalLetters @Protein_Sequence, @CapitalLetterCount = @ProteinCoverageResidueCountHighAbu OUTPUT
				End
*/

				exec CountCapitalLetters @Protein_Sequence, @CapitalLetterCount = @ProteinCoverageResidueCountHighAbu OUTPUT

				--
				-- Lookup the potential protein coverage fraction from T_Protein_Coverage
				-- Protein coverage values are stored precomputed in this table, using PMT_Quality_Score >= 0 and >= 0.001
				Set @PotentialProteinCoverageFraction = Null
				--
				SELECT TOP 1 @PotentialProteinCoverageFraction = Coverage_PMTs
				FROM T_Protein_Coverage
				WHERE Ref_ID = @LastRefID AND PMT_Quality_Score_Minimum >= @MinimumPotentialPMTQualityScore
				ORDER BY PMT_Quality_Score_Minimum ASC
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				If @myRowCount = 0
				Begin
					-- Entry not found with PMT_Quality_Score_Minimum >= @MinimumPotentialPMTQualityScore
					-- See if any entries exist for @LastRefID; sort descending this time
					
					SELECT TOP 1 @PotentialProteinCoverageFraction = Coverage_PMTs
					FROM T_Protein_Coverage
					WHERE Ref_ID = @LastRefID
					ORDER BY PMT_Quality_Score_Minimum DESC
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					
				End
				
				If IsNull(@PotentialProteinCoverageFraction, -1) >= 0
					Set @PotentialProteinCoverageResidueCount = @PotentialProteinCoverageFraction * Convert(float, @ProteinSequenceLength)
				Else
					Set @PotentialProteinCoverageResidueCount = Null


				-- Record the computed Protein Coverage values in #Protein_Coverage	
				UPDATE #Protein_Coverage
				SET Protein_Coverage_Residue_Count = @ProteinCoverageResidueCount,
					Protein_Coverage_Fraction = @ProteinCoverageResidueCount / Convert(float, @ProteinSequenceLength),
					Protein_Coverage_Fraction_High_Abundance = @ProteinCoverageResidueCountHighAbu / Convert(float, @ProteinSequenceLength),
					Potential_Protein_Coverage_Residue_Count = @PotentialProteinCoverageResidueCount,
					Potential_Protein_Coverage_Fraction = @PotentialProteinCoverageFraction
				WHERE Ref_ID = @LastRefID
				--	
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				If @myError <> 0 
				Begin
					Set @message = 'Error updating the Protein coverage values in the #Protein_Coverage temporary table'
					Set @myError = 142
					Goto Done
				End

			End
		End
	End
	
	-- Copy the Protein Coverage Values from #Protein_Coverage to #ProteinAbundanceSummary
	UPDATE #ProteinAbundanceSummary
	SET Protein_Coverage_Residue_Count = #Protein_Coverage.Protein_Coverage_Residue_Count,
		Protein_Coverage_Fraction = #Protein_Coverage.Protein_Coverage_Fraction,
		Protein_Coverage_Fraction_High_Abundance = #Protein_Coverage.Protein_Coverage_Fraction_High_Abundance,
		Potential_Protein_Coverage_Residue_Count = #Protein_Coverage.Potential_Protein_Coverage_Residue_Count,
		Potential_Protein_Coverage_Fraction = #Protein_Coverage.Potential_Protein_Coverage_Fraction
	FROM #ProteinAbundanceSummary INNER JOIN
			#Protein_Coverage ON #ProteinAbundanceSummary.Ref_ID = #Protein_Coverage.Ref_ID
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0 
	Begin
		Set @message = 'Error copying the Protein coverage values from #Protein_Coverage to #ProteinAbundanceSummary'
		Set @myError = 143
		Goto Done
	End
	
Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessWorkStepG] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessWorkStepG] TO [MTS_DB_Lite] AS [dbo]
GO
