/****** Object:  StoredProcedure [dbo].[CleavageRule] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE dbo.CleavageRule
/****************************************************
**	Desc: Determines if a certain point in a peptide is a cleavage location
**
**		- A C D E F G H I K -
**		 0 1 2 3 4 5 6 7 8 9 
**
**	Return values: 
**		0 cleavage does not occur at given position
**		1 if cleavage does occur
**
**	Parameters:
**		@ref_id - Ref_ID to be used in looking up Protein in 
**			T_Proteins
**		@position - position to evaluate for cleavage site,
**			as described above; if the peptide is at the N-terminus of the protein, then @position = 0
**    
**	Author: KAL
**	Date: 7/17/2003
**		  9/18/2004 mem - Replaced ORF references with Protein references and added @ProteinLength parameter
**		  3/26/2005 mem - Made @ProteinLength a required parameter (the calling procedure must lookup the value in T_Proteins)
**						  Added parameter @TerminusState
**						  Now returning 0 if the residue is at the N- or C-terminus of the protein
**
*****************************************************/
	(
		@ref_ID int,
		@position int,
		@ProteinLength int,					-- The calling procedure must have already determined this value
		@TerminusState int=0 OUTPUT		-- Will be 1 if @position is at the N-terminus, 2 if at the C-terminus, otherwise 0
	)
AS
	declare @cleavageAA char(2)
	
	set @TerminusState = 0
			
	--deal with bad inputs
	if @position < 0 OR @position > @proteinLength
		return 0
	
	-- Lookup the amino acid to examine for cleavage site, and the following amino acid (so we can test the Proline rule)
	SELECT @cleavageAA = substring(Protein_Sequence, @position, 2)
	FROM T_Proteins
	WHERE Ref_ID = @ref_ID
		
	if @@rowCount <> 1
		return 0

	
	-- If before Protein start or at end of Protein, then set @TerminusState = 1 or 2 and return 0
	-- Calling procedure will need to determine whether peptide is tryptic or not based on both ends of the peptide
	if @position = 0
	Begin
		Set @TerminusState = 1
		return 0
	End
	else
		if @position >= @proteinLength
		Begin
			Set @TerminusState = 2
			return 0
		End

	--now we know that two characters were successfully selected
	
	-- If K or R followed by P, then it's not a valid cleavage point
	-- Otherwise, if the first char is R or K, then it is a cleavage point
	if @cleavageAA LIKE '[KR]P'
		return 0
	else
	if @cleavageAA LIKE '[KR]%'
		return 1
	else
		return 0
		


GO
GRANT VIEW DEFINITION ON [dbo].[CleavageRule] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CleavageRule] TO [MTS_DB_Lite] AS [dbo]
GO
