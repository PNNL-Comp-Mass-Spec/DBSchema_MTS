/****** Object:  StoredProcedure [dbo].[GetPeptideIndexes] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetPeptideIndexes
/****************************************************
**	Desc: 
**			Given a peptide and Ref_ID for a Protein, returns the
**			index of the first character of the peptide in the Protein
**			and the index for the last character of the peptide
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**			@peptide - peptide to find indexes for
**			@RefID - Ref_ID to look up protein sequence in T_Proteins
**
**	Outputs:
**			@startIndex - character index for first amino acid of peptide in Protein
**			@endIndex - character index for last amino acid of peptide in Protein
**			@message - error message if something went wrong
**			
**	Auth:	kal
**	Date:	07/11/2003
**			09/18/2004 mem - Replaced ORF references with Protein references
**			04/08/2008 mem - Renamed @RefID parameter to be consistent with NamePeptides
**
*****************************************************/
(
	@peptide varchar(850),
	@RefID int,
	@startIndex int = -1 output,
	@endIndex int = -1 output,
	@message varchar(512) = ''output
)
AS
	SET NOCOUNT ON
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	-- Find start index
	-- Use patindex instead of charindex because
	-- Protein_Sequence is a text field
	
	SELECT @startIndex = PatIndex('%' + @peptide + '%', Protein_Sequence)
	FROM T_Proteins 
	WHERE Ref_ID = @RefID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if (@myError <> 0)
	begin
		set @message = 'Error in computing peptide indexes.'
		goto done
	end
	
	if (@myRowCount <> 1)
	begin
		set @myError = 76002
		set @message = 'Invalid number of rows.  ' + LTrim(RTrim(Str(@myRowCount))) + ' found for Protein Ref_ID ' + LTrim(RTrim(Str(@RefID))) + '.'
		goto done
	end
	
	-- Check for peptide not found in Protein
	if @startIndex = 0
	begin
		set @myError = 76005
		set @message = 'Peptide not found in Protein.  ' + 'Incompatible peptide ' + @peptide + ' and Protein Ref_ID ' + LTrim(RTrim(Str(@RefID))) + '.'
	end
	
	--set endIndex to the index of last amino acid, not the one following it	
	set @endIndex = @startIndex + len(@peptide) - 1
	
done:
	RETURN @myError


GO
GRANT VIEW DEFINITION ON [dbo].[GetPeptideIndexes] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetPeptideIndexes] TO [MTS_DB_Lite] AS [dbo]
GO
