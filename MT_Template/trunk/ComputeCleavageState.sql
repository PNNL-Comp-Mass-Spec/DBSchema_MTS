/****** Object:  StoredProcedure [dbo].[ComputeCleavageState] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE Procedure dbo.ComputeCleavageState
/****************************************************
**
**	Desc: Examines peptide sequence against 
**		  cleavage filter
**
**	Return values: 1: matched filter, 0: did not match filter 
**
**	Parameters:
**		@ref_id - Protein sequence that peptide is located in
**		@startIndex - Starting residue index of peptide within the protein; if at the N-terminus, then should be 1
**		@endIndex - Ending residue index of the peptide within protein; if at the C-terminus, then should be equal to @ProteinLength
**	
**		Auth: grk
**		Date: 11/1/2001
**    
**		Modified 7/09/2003 kal
**				 9/18/2004 mem - Added @ProteinLength parameter
**				 3/26/2005 mem - Now looking up @proteinLength in this procedure (if not provided via @ProteinLength)
**								 Now custom handling N- and C-terminal peptides in this procedure
**
*****************************************************/
	@ref_id int,
	@startIndex int,
	@endIndex int,
	@ProteinLength int = 0		-- Will use this value for the protein length if > 0 (performance increase attained by caching this value between calls)
As
	set nocount on 
	declare @returnVal int
	set @returnVal = 0
	
	declare @curVal int
	declare @prefixIndex int
	
	-- Lookup @ProteinLength if zero
	if IsNull(@ProteinLength, 0) = 0
	Begin
		SELECT @proteinLength = datalength(Protein_Sequence)
		FROM T_Proteins
		WHERE Ref_ID = @ref_ID
		
		if @@rowCount <> 1
			return 0
	End
	
	if @startIndex <= 1
	Begin
		-- At N-terminus of peptide
		if @endIndex = @ProteinLength
		Begin
			-- Peptide spans the entire length of the protein; mark as fully tryptic
			set @returnVal = 2
		End
		else
		Begin
			-- At N-terminus of peptide; only need to check @endIndex
			EXEC @curVal = CleavageRule @ref_ID, @endIndex, @ProteinLength
			if @curVal > 0
				set @returnVal = 2			-- At N-terminus, and ending in a valid cleavage point, so peptide is fully tryptic
		End
	End
	else
	Begin
		if @endIndex >= @ProteinLength
		Begin
			-- At C-terminus of peptide; only need to check @startIndex-1
			set @prefixIndex = @startIndex-1
			EXEC @curVal = CleavageRule @ref_ID, @prefixIndex, @ProteinLength
			if @curVal > 0
				set @returnVal = 2			-- At C-terminus, and starting with a valid clevage point, so peptide is fully tryptic
		End
		Else
		Begin
			-- Test the start of the peptide for being a valid cleavage point
			-- Pass @startIndex-1 to CleavageRule since the residue to examine is one residue before the start of the peptide	
			set @prefixIndex = @startIndex-1
			EXEC @curVal = CleavageRule @ref_id, @prefixIndex, @ProteinLength
			set @returnVal = @curVal
			
			-- Test the end of the peptide for being a valid cleavage point
			EXEC @curVal = CleavageRule @ref_ID, @endIndex, @ProteinLength
			set @returnVal = @returnVal + @curVal
		End
	End
		
	return @returnVal


GO
