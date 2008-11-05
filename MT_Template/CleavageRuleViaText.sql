/****** Object:  StoredProcedure [dbo].[CleavageRuleViaText] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.CleavageRuleViaText
/****************************************************
**	Desc:	For a given residue and following residue,
**			determines if the pair is a valid cleavage point
**			in a peptide.  However, if @Residue = '-' or
**			@NextResidue = '-' then returns 0 and sets
**			@TerminusState to 1 or 2
**
**	Match Spec Hints:
**		[KR] means to match K or R
**		[^P] means the residue cannot be P
**		[A-Z] means to match anything
**		Empty string means to match nothing (and will thus always return 0 for not a cleavage point)
**
**	Return values: 
**		0 cleavage does not occur at given position
**		1 if cleavage does occur
**
**	Auth:	mem
**	Date:	08/09/2006
**
*****************************************************/
(
	@Residue char,
	@NextResidue char,
	@TerminusState tinyint=0 OUTPUT,					-- Will be 1 if @Residue is at the N-terminus, 2 if @NextResidue is at the C-terminus, 3 if both are terminii, otherwise 0
	@LeftResidueMatchSpec varchar(32) = '[KR]',			-- Must be a valid Like clause
	@RightResidueMatchSpec varchar(32) = '[^P]'			-- Must be a valid Like clause
)
AS
	Set NoCount On

	set @TerminusState = 0

	-- If before Protein start or at end of Protein, then set @TerminusState = 1 or 2 and return 0
	-- Calling procedure will need to determine whether peptide is tryptic or not based on both ends of the peptide
	If @Residue = '-'
	Begin
		If @NextResidue = '-'
			Set @TerminusState = 3
		Else
			Set @TerminusState = 1
		Return 0
	End
	Else
	Begin
		If @NextResidue = '-'
		Begin
			Set @TerminusState = 2
			Return 0
		End
	End
	
	-- If @residue matches @LeftResidueMatchSpec and @NextResidue matches @RightResidueMatchSpec
	--  then this is a valid cleavage point
	-- Otherwise, it is not
	If @residue LIKE @LeftResidueMatchSpec
	Begin
		If @NextResidue LIKE @RightResidueMatchSpec
			Return 1
		Else
			Return 0
	End
	Else
		Return 0


GO
GRANT VIEW DEFINITION ON [dbo].[CleavageRuleViaText] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[CleavageRuleViaText] TO [MTS_DB_Lite]
GO
