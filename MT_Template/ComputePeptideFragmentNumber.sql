/****** Object:  StoredProcedure [dbo].[ComputePeptideFragmentNumber] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.ComputePeptideFragmentNumber
/****************************************************
**
**	Desc:	Determines the peptide fragment number of a given residue
**			given its index in a protein sequence.  Currently assumes tryptic rules.
**
**			For example, given protein ACDKMNPRSTV, 
**			   tryptic peptide 1 is ACDK (residues 1 through 4)
**			   tryptic peptide 2 is MNPR (residues 5 through 8)
**			 & tryptic peptide 3 is STV  (residues 9 through 11)
**
**			Therefore, calling this SP with @residueIndex 1 through 4 returns 1,
**			calling with @residueIndex 5 through 8 returns 2, and
**			calling with @residueIndex 9 through 1 returns 3
**
**	Return value: The tryptic peptide number for @residueIndex
**
**	Parameters:
**		@ref_id - lookup key for Protein that peptide occurs in
**		@residueIndex - residue index to examine
**
**  Output:	the number of cleavage points
**
**	Auth:	kal
**	Date:	07/14/2003   
**			09/18/2004 mem - Replaced ORF references with Protein references and added @ProteinLength parameter
**			03/26/2005 mem - Updated to accommodate new behavior of SP CleavageRule for N-terminal residues
**			08/10/2006 mem - Now calling ComputeCleavagesInPeptide to count the number of cleavage points
**
*****************************************************/
(
	@ref_id int,
	@residueIndex int,
	@ProteinLength int = 0		-- Will use this value for the protein length if > 0
	--@cleavageAminoAcids varchar(32) = 'RK-'
)
AS
	SET NOCOUNT ON
	
	Declare @ChunkSize int
	Set @ChunkSize = 2000
	
	declare @currentIndexStart int
	declare @currentIndexEnd int
	
	declare @curVal int
	set @curVal = 0

	-- Initialize Count to 1 since the first peptide is peptide #1
	declare @count int
	set @count = 1

	-- Lookup @ProteinLength if zero
	If IsNull(@ProteinLength, 0) = 0
		SELECT @proteinLength = datalength(Protein_Sequence)
		FROM T_Proteins
		WHERE Ref_ID = @ref_id
	
	-- Validate @residueIndex
	If @residueIndex > @ProteinLength
		Set @residueIndex = @ProteinLength

	-- Call ComputeCleavagesInPeptide for the residues in protein @ref_id
	--  up to index @residueIndex, processing the data in chunks of size @ChunkSize
	--	
	Set @currentIndexStart = 1
	While @currentIndexStart < @residueIndex
	Begin
		Set @currentIndexEnd = @currentIndexStart + @ChunkSize-1
		If @currentIndexEnd >= @residueIndex
			Set @currentIndexEnd = @residueIndex-1

		exec @curVal = ComputeCleavagesInPeptide @ref_id, @currentIndexStart, @currentIndexEnd, @ProteinLength
		set @count = @count + @curVal
		
		Set @currentIndexStart = @currentIndexStart + @ChunkSize
	End
	
	RETURN @count


GO
GRANT VIEW DEFINITION ON [dbo].[ComputePeptideFragmentNumber] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[ComputePeptideFragmentNumber] TO [MTS_DB_Lite]
GO
