SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ComputeCleavagesInPeptide]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ComputeCleavagesInPeptide]
GO



CREATE PROCEDURE dbo.ComputeCleavagesInPeptide
/****************************************************
**
**	Desc: Find the number of cleavage points in a peptide
**		given by start and end indexes into its
**		associated Protein
**
**	Return value: the number of cleavages in the peptide
**		including the one at its end (if applicable),
**		but never the one before the peptide starts
**
**	Parameters:
**		@ref_id - lookup key for Protein that peptide occurs in
**		@startIndex - index to start looking for cleavages
**		@endIndex - index to stop looking for cleavages
**
**  Output:	the number of cleavage points
**
**		Auth: kal
**		Date: 7/14/2003
**			  9/18/2004 mem - Replaced ORF references with Protein references and added @ProteinLength parameter
**			  3/26/2005 mem - Now looking up @ProteinLength before calling CleavageRule
**							  Updated to accommodate new behavior of SP CleavageRule for C-terminal residues
*****************************************************/
	(
		@ref_id int,
		@startIndex int,
		@endIndex int,
		@ProteinLength int = 0		-- Will use this value for the protein length if > 0
		--@peptide varchar(900),
		--@cleavageAminoAcids varchar(32) = 'RK-'
	)

AS
	SET NOCOUNT ON
	declare @count int
	set @count = 0
	
	declare @curIndex int
	set @curIndex = @startIndex
	
	declare @curValue int
	set @curValue = 0

	-- Lookup @ProteinLength if zero
	if IsNull(@ProteinLength, 0) = 0
	Begin
		SELECT @proteinLength = datalength(Protein_Sequence)
		FROM T_Proteins
		WHERE Ref_ID = @ref_ID
		
		if @@rowCount <> 1
			return 0
	End

	
	while @curIndex <= @endIndex
	begin
		EXEC @curValue = CleavageRule @ref_id, @curIndex, @ProteinLength
		set @count = @count + @curValue
		set @curIndex = @curIndex + 1
	end
	
	if @endIndex = @ProteinLength
		set @count = @count + 1
		
	RETURN @count



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

