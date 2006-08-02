SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ComputeCleavagesInProtein]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ComputeCleavagesInProtein]
GO



CREATE PROCEDURE dbo.ComputeCleavagesInProtein
/****************************************************
**
**	Desc: Find the number of cleavage points in a Protein
**		up to a certain index.
**
**	Return value: the number of cleavages before the
**		given index
**
**	Parameters:
**		@cleavageAminoAcids - possible amino acids
**			that cleavages can occur after
**		@ref_id - key for looking up protein sequence
**		@peptideStartIndex - index at which to stop
**			looking for cleavages
**
**  Output:	the number of cleavage points
**
**		Auth: kal
**		Date: 7/14/2003   
**			  9/18/2004 mem - Replaced ORF references with Protein references and added @ProteinLength parameter
**			  3/26/2005 mem - Updated to accommodate new behavior of SP CleavageRule for N-terminal residues
**
*****************************************************/
(
	--@cleavageAminoAcids varchar(32) = 'RK-',
	@ref_id int,
	@peptideStartIndex int,
	@ProteinLength int = 0		-- Will use this value for the protein length if > 0
)
AS
	SET NOCOUNT ON
	
	If IsNull(@ProteinLength, 0) = 0
		SELECT @proteinLength = datalength(Protein_Sequence)
		FROM T_Proteins
		WHERE Ref_ID = @ref_id
	
	declare @currentIndex int
	set @currentIndex = 1
	
	declare @curVal int
	set @curVal = 0
	
	declare @count int
	set @count = 1
	
	while @currentIndex < @peptideStartIndex
	begin
		EXEC @curVal = CleavageRule @ref_id, @currentIndex, @ProteinLength
		set @count = @count + @curVal
		set @currentIndex = @currentIndex + 1
	end
	RETURN @count



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

