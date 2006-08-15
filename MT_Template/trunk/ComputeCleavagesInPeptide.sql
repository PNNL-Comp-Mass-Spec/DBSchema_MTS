/****** Object:  StoredProcedure [dbo].[ComputeCleavagesInPeptide] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.ComputeCleavagesInPeptide
/****************************************************
**
**	Desc:	Find the number of cleavage points in a peptide
**			given by start and end indexes into its associated Protein
**
**	Returns:	The number of cleavages in the peptide including the one 
**				at its end (if applicable), but never the one before the peptide starts
**
**	Parameters:
**		@ref_id - lookup key for Protein that peptide occurs in
**		@startIndex - index to start looking for cleavages
**		@endIndex - index to stop looking for cleavages
**
**  Output:	the number of cleavage points
**
**	Auth:	kal
**	Date:	07/14/2003
**			09/18/2004 mem - Replaced ORF references with Protein references and added @ProteinLength parameter
**			03/26/2005 mem - Now looking up @ProteinLength before calling CleavageRule
**						   - Updated to accommodate new behavior of SP CleavageRule for C-terminal residues
**			08/10/2006 mem - Now calling CountMissedCleavagePoints if @endIndex - @startIndex is less than 4000
**
*****************************************************/
(
	@ref_id int,
	@startIndex int,
	@endIndex int,
	@ProteinLength int = 0			-- Will use this value for the protein length if > 0
	--@peptide varchar(4000),
	--@cleavageAminoAcids varchar(32) = 'RK-'
)
AS
	SET NOCOUNT ON
	
	declare @curIndex int
	
	declare @curValue int
	set @curValue = 0
	
	declare @count int
	set @count = 0

	-- Lookup @ProteinLength if zero
	if IsNull(@ProteinLength, 0) = 0
	Begin
		SELECT @proteinLength = DataLength(Protein_Sequence)
		FROM T_Proteins
		WHERE Ref_ID = @ref_ID
		
		if @@rowCount <> 1
			return 0
	End

	Declare @UseOldMethod tinyint
	Set @UseOldMethod = 0

	If @UseOldMethod = 1 Or @endIndex - @startIndex >= 4000
	Begin	
		set @curIndex = @startIndex
		while @curIndex <= @endIndex
		begin
			EXEC @curValue = CleavageRule @ref_id, @curIndex, @ProteinLength
			set @count = @count + @curValue
			set @curIndex = @curIndex + 1
		end
	End
	Else
	Begin
		Declare @peptide varchar(4000)
		Declare @Residue varchar(1)
		Declare @SuffixAA varchar(1)
		
		SELECT  @peptide = SubString(Protein_Sequence, @startIndex, @endIndex - @startIndex + 1),
				@SuffixAA = CASE WHEN @endIndex < @proteinLength
							THEN SubString(Protein_Sequence, @endIndex+1, 1)
							ELSE '-'
							END
		FROM T_Proteins
		WHERE Ref_ID = @ref_ID
		
		if @@rowCount <> 1
			return 0

		-- Count the number of missed cleavages in the peptide
		Exec @count = CountMissedCleavagePoints @peptide, @CheckForPrefixAndSuffixResidues = 0

		-- Determine whether the C-terminus is a cleavage point
		Set @Residue = Right(@peptide, 1)
		EXEC @curValue = CleavageRuleViaText @Residue, @SuffixAA
		set @count = @count + @curValue
	End

	-- If @endIndex is at the end of the protein, then CleavageRule will return 0 for @curValue
	-- However, we want to increment @count if @endIndex is at the end of the protein, so check for this
	if @endIndex = @ProteinLength
		set @count = @count + 1
			
	RETURN @count


GO
