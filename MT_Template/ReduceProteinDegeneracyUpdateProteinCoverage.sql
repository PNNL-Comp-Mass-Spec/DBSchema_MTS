/****** Object:  StoredProcedure [dbo].[ReduceProteinDegeneracyUpdateProteinCoverage] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE ReduceProteinDegeneracyUpdateProteinCoverage
/****************************************************	
**  Desc:	Updates Protein Coverage values while reducing protein degeneracy
**
**		The calling procedure must create and populate table:
**
**			CREATE TABLE #TmpDegeneracyProteinCoverage (
**				Ref_ID int NOT NULL,
**				Protein_Sequence varchar(8000) NOT NULL,
**				Protein_Coverage_Residue_Count int NULL,
**				Protein_Coverage_Fraction real NULL
**			)
**
**		When @ComputationMode = 1, this procedure also utilizes table #TmpAMTtoProteinMap
**		by only processing proteins that have a peptide in #TmpAMTtoProteinMap with Valid = -1
**
**		CREATE TABLE #TmpAMTtoProteinMap (
**			Mass_Tag_ID int not null,
**			Ref_ID int not null,
**			Valid smallint not null
**		)
**  Return values: 0 if success, otherwise, error code
**
**  Auth:	mem
**	Date:	11/02/2011 mem - Initial Version
**
****************************************************/
(
	@ComputationMode tinyint = 0,				-- 0 means to compute protein coverage for all proteins; 1 means to remove peptides from mapping to proteins and re-compute protein coverage
	@message varchar(512) = '' output
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

 	Declare @RefID int,
 	        @Continue tinyint,
 			@Protein_Sequence_Full varchar(8000),
 			@ProteinCoverageResidueCount int,
 			@ProteinSequenceLength int

	If @ComputationMode = 0
	Begin
		-- Process all proteins in #TmpDegeneracyProteinCoverage to compute coverage using all peptides in #TmpAMTtoProteinMap with Valid = 1
		UPDATE #TmpDegeneracyProteinCoverage
		Set Process = 1
		WHERE Process <> 1
	
	End
	Else
	Begin
		-- Process each Protein in #TmpDegeneracyProteinCoverage that has a peptide in #TmpAMTtoProteinMap with Valid = -1
		-- Change Protein residues to lowercase for each of these peptides since we no longer want to associate them with the given protein

		UPDATE #TmpDegeneracyProteinCoverage
		Set Process = 0
		WHERE Process <> 0
		
		UPDATE #TmpDegeneracyProteinCoverage
		SET Process = 1
		FROM #TmpDegeneracyProteinCoverage
		     INNER JOIN #TmpAMTtoProteinMap
		       ON #TmpAMTtoProteinMap.Ref_ID = #TmpDegeneracyProteinCoverage.Ref_ID
		WHERE #TmpAMTtoProteinMap.Valid = -1
		
	End
	
	-- First determine the minimum Ref_ID value
	Set @RefID = -1
	--
	SELECT @RefID = MIN(Ref_ID) - 1
	FROM #TmpDegeneracyProteinCoverage
	
	-- Now step through the table
	Set @Continue = 1
	While @Continue = 1
	Begin -- <a>
		SELECT TOP 1 @RefID = Ref_ID,
					 @Protein_Sequence_Full = Protein_Sequence
		FROM #TmpDegeneracyProteinCoverage
		WHERE Ref_ID > @RefID AND Process = 1
		ORDER BY Ref_ID
		--	
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error while obtaining the next Ref_ID from the #TmpDegeneracyProteinCoverage temporary table'
			Set @myError = 139
			Goto Done
		End
		
		IF @myRowCount <> 1
			Set @Continue = 0
		Else
		Begin -- <b>
			Set @ProteinSequenceLength = Len(@Protein_Sequence_Full)
			
			If @ProteinSequenceLength > 0
			Begin -- <c>
				
				If @ComputationMode = 0
				Begin -- <d1>
					-- Change protein sequence residues from Lower to Upper case
					--
					SELECT @Protein_Sequence_Full = REPLACE(@Protein_Sequence_Full, T_Mass_Tags.Peptide, UPPER(T_Mass_Tags.Peptide))
					FROM #TmpAMTtoProteinMap
					     INNER JOIN T_Mass_Tags
					       ON #TmpAMTtoProteinMap.Mass_Tag_ID = T_Mass_Tags.Mass_Tag_ID
					WHERE #TmpAMTtoProteinMap.Ref_ID = @RefID AND
					      #TmpAMTtoProteinMap.Valid > 0
					--	
					SELECT @myError = @@error, @myRowCount = @@rowcount
					--
					If @myError <> 0 
					Begin
						Set @message = 'Error while capitalizing the protein sequence for Protein_Coverage use'
						Set @myError = 140
						Goto Done
					End
				End -- </d1>
				Else
				Begin -- <d2>
					-- Change protein sequence residues from Upper to Lower case
					
					SELECT @Protein_Sequence_Full = REPLACE(@Protein_Sequence_Full, T_Mass_Tags.Peptide, LOWER(T_Mass_Tags.Peptide))
					FROM #TmpAMTtoProteinMap
					     INNER JOIN T_Mass_Tags
					       ON #TmpAMTtoProteinMap.Mass_Tag_ID = T_Mass_Tags.Mass_Tag_ID
					WHERE #TmpAMTtoProteinMap.Ref_ID = @RefID AND
					      #TmpAMTtoProteinMap.Valid = -1
					
				End -- </d2>
				
				Set @ProteinCoverageResidueCount = 0
				
				exec CountCapitalLetters @Protein_Sequence_Full, @CapitalLetterCount = @ProteinCoverageResidueCount OUTPUT

				-- Record the computed Protein Coverage values in #TmpDegeneracyProteinCoverage	
				UPDATE #TmpDegeneracyProteinCoverage
				SET Protein_Sequence = @Protein_Sequence_Full,
				    Protein_Coverage_Residue_Count = @ProteinCoverageResidueCount,
					Protein_Coverage_Fraction = @ProteinCoverageResidueCount / Convert(float, @ProteinSequenceLength)
				WHERE Ref_ID = @RefID
				--	
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				If @myError <> 0 
				Begin
					Set @message = 'Error updating the Protein coverage values in the #TmpDegeneracyProteinCoverage temporary table'
					Set @myError = 142
					Goto Done
				End

			End -- </c>
		End -- </b>
	End -- </a>
		
Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[ReduceProteinDegeneracyUpdateProteinCoverage] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ReduceProteinDegeneracyUpdateProteinCoverage] TO [MTS_DB_Lite] AS [dbo]
GO
