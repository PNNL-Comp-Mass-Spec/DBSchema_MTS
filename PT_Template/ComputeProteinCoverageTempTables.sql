/****** Object:  StoredProcedure [dbo].[ComputeProteinCoverageTempTables] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE ComputeProteinCoverageTempTables
/****************************************************
** 
**	Desc: 	Computes the protein coverage for the proteins in temporary table #Tmp_FilteredProteins
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth: 	mem
**	Date: 	11/13/2013 mem - Initial version
**    
*****************************************************/
(
	@numProteinsToProcess int = -1,
	@message varchar(255) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	set @message = ''

	If @numProteinsToProcess < 0
		Set @numProteinsToProcess = 1000000000

	--------------------------------------------------------------
	-- Compute the protein coverage for each protein
	--------------------------------------------------------------

	Declare @Continue tinyint = 1
	Declare @RefID int = -1000000000
	
	Declare @ProcessCount int = 0
	Declare @ProteinSequence varchar(max)
	Declare @ProteinSequenceLength int
	Declare @ProteinCoverageResidueCount int
	
	While @Continue = 1 AND @ProcessCount < @numProteinsToProcess
	Begin -- <c>
		-- Get next protein
		SELECT TOP 1 @RefID = Ref_ID
		FROM #Tmp_FilteredProteins
		WHERE Ref_ID > @RefID AND Coverage_PMTs Is Null
		ORDER By Ref_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount < 1
			Set @Continue = 0
		Else
		Begin -- <d>
			-- Get protein sequence for given Protein
			--
			SELECT	@ProteinSequence = IsNull(Protein_Sequence, '')
			FROM	T_Proteins
			WHERE	Ref_ID = @RefID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			Set @ProteinSequenceLength = Len(@ProteinSequence)
			
			If @myRowCount = 1 And @ProteinSequenceLength > 0
			Begin -- <e>
				Set @ProteinSequence = Lower(@ProteinSequence)
				
				-- Work through list of peptides for given Protein
				--   substituting upper case version of each peptide into the protein string
				--
				SELECT	@ProteinSequence = REPLACE (@ProteinSequence, #Tmp_FilteredPeptides.Peptide, #Tmp_FilteredPeptides.Peptide)
				FROM	#Tmp_FilteredPeptides
				WHERE   #Tmp_FilteredPeptides.Ref_ID = @RefID
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				-- Count the number of uppercase letters in @ProteinSequence
				If @myRowCount > 0
					exec CountCapitalLetters @ProteinSequence, @CapitalLetterCount = @ProteinCoverageResidueCount OUTPUT
				else
					Set @ProteinCoverageResidueCount = 0

				-- Compute the coverage and save to #Tmp_FilteredProteins
				UPDATE #Tmp_FilteredProteins
				Set Coverage_PMTs = @ProteinCoverageResidueCount / Convert(float, @ProteinSequenceLength)
				WHERE Ref_ID = @RefID
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				Set @ProcessCount = @ProcessCount + 1			
			End -- </e>
		End -- </d>

	End -- </c>


Done:
	return @myError

GO
