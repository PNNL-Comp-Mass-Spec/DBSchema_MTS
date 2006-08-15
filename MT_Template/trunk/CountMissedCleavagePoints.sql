/****** Object:  StoredProcedure [dbo].[CountMissedCleavagePoints] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.CountMissedCleavagePoints
/****************************************************
**	Desc:	Counts the number of missed cleavage points in @Peptide
**
**	Match Spec Hints:
**		[KR] means to match K or R
**		[^P] means the residue cannot be P
**		[A-Z] means to match anything
**		Empty string means to match nothing (and will thus always return 0 for not a cleavage point)
**
**	Return values: 
**		The number of missed cleavage points
**
**	Auth:	mem
**	Date:	08/10/2006
**
*****************************************************/
(
	@Peptide varchar(4000),								-- Can be of the form X.ACDEF.X or simply ACDEF
	@CheckForPrefixAndSuffixResidues tinyint = 1,		-- If 1, then will remove the characters outside leading and trailing periods; if the calling procedure has already done this, then set to 0
	@LeftResidueMatchSpec varchar(32) = '[KR]',			-- Must be a valid Like clause
	@RightResidueMatchSpec varchar(32) = '[^P]'			-- Must be a valid Like clause
)
AS
	Set NoCount On

	Declare @CharLoc int
	Declare @PeptideLength int

	Declare @Residue char
	Declare @NextResidue char

	Declare @TerminusState tinyint
	Declare @CleavageRuleMatch int
	Declare @MissedCleavageCount int
	
	Set @Peptide = IsNull(@Peptide, '')
	Set @MissedCleavageCount = 0
	
	-- Possibly check for and remove any prefix or suffix residues
	If IsNull(@CheckForPrefixAndSuffixResidues, 1) <> 0
		Exec SplitPrefixAndSuffixFromSequence @Peptide, @Peptide OUTPUT

	-- Step through @Peptide and count the number of cleavage points
	Set @PeptideLength = Len(@Peptide)
	Set @CharLoc = 1
	While @CharLoc < @PeptideLength
	Begin
		Set @Residue = SubString(@Peptide, @CharLoc, 1)
		Set @NextResidue = SubString(@Peptide, @CharLoc+1, 1)
		
		Exec @CleavageRuleMatch = CleavageRuleViaText	@Residue,
														@NextResidue,
														@TerminusState Output, 
														@LeftResidueMatchSpec,
														@RightResidueMatchSpec

		If @CleavageRuleMatch <> 0
			Set @MissedCleavageCount = @MissedCleavageCount + 1
			
		Set @CharLoc = @CharLoc + 1
	End
	
	Return @MissedCleavageCount


GO
