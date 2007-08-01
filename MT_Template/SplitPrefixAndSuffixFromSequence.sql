/****** Object:  StoredProcedure [dbo].[SplitPrefixAndSuffixFromSequence] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.SplitPrefixAndSuffixFromSequence
/****************************************************
**	Desc:	Looks for and removes the prefix and suffix residues from @Peptide
**			 @PrimarySequence will contain the clean sequence
**			 @PrefixResidue and @SuffixResidue will contain the prefix and suffix residues
**
**	Return values: 
**		Returns 1 if success, 0 if prefix and suffix residues were not found
**
**	Auth:	mem
**	Date:	08/10/2006
**
*****************************************************/
(
	@Peptide varchar(4000),							-- Can be of the form X.ACDEF.X or simply ACDEF
	@PrimarySequence varchar(4000)='' OUTPUT,
	@PrefixResidue varchar(16)='' OUTPUT,			-- Will be more than one character if the period in @Peptide is after the second character
	@SuffixResidue varchar(16)='' OUTPUT			-- Will be more than one character if the period in @Peptide is before the second to the last character
)
AS

    -- Examines @Peptide and splits apart into prefix, primary sequence, and suffix
    -- If more than one character is present before the first period or after the last period, then all characters are returned

    Declare @PeriodLoc1 Integer
    Declare @PeriodLoc2 Integer
	
	Declare @PeptideLength int
	
    Set @PrefixResidue = ''
    Set @SuffixResidue = ''
    Set @PrimarySequence = ''

    If Len(IsNull(@Peptide, '')) = 0
        Return 0
    Else
    Begin -- <a>
		Set @PeptideLength = Len(@Peptide)
        Set @PrimarySequence = @Peptide
        
        -- See if @Peptide contains two periods
        Set @PeriodLoc1 = CharIndex('.', @Peptide)
        If @PeriodLoc1 >= 1
        Begin -- <b>
			-- Find the next period
            Set @PeriodLoc2 = CharIndex('.', @Peptide, @PeriodLoc1 + 1)

            If @PeriodLoc2 > @PeriodLoc1 + 1
            Begin -- <c1>
                -- Sequence contains two periods with letters between the periods, 
                -- For example, A.BCDEFGHIJK.L or ABCD.BCDEFGHIJK.L
                -- Extract out the text between the periods
                Set @PrimarySequence = SubString(@Peptide, @PeriodLoc1 + 1, @PeriodLoc2 - @PeriodLoc1 - 1)
                If @PeriodLoc1 > 1
                    Set @PrefixResidue = SubString(@Peptide, 1, @PeriodLoc1-1)
                
                Set @SuffixResidue = SubString(@Peptide, @PeriodLoc2+1, @PeptideLength)

                Return 1
            End -- </c1>
            

			If @PeriodLoc2 = @PeriodLoc1 + 1
			Begin -- <c2>
				-- Peptide contains two periods in a row
				If @PeriodLoc1 <= 2
				Begin
					Set @PrimarySequence = ''

					If @PeriodLoc1 > 1
						Set @PrefixResidue = SubString(@Peptide, 1, @PeriodLoc1-1)
					
					Set @SuffixResidue = SubString(@Peptide, @PeriodLoc2 + 1, @PeptideLength)

					Return 1
				End
				Else
					-- Leave the sequence unchanged
					Return 0
            End -- </c2>
            
            -- Peptide only contains one period
            If @PeriodLoc1 = 1
            Begin -- <c3>
                Set @PrimarySequence = Substring(@Peptide, 2, @PeptideLength)
                Return 1
            End -- </c3>
            
            If @PeriodLoc1 = @PeptideLength
            Begin -- <c4>
                Set @PrimarySequence = Substring(@Peptide, 1, @PeriodLoc1-1)
				Return 1
			End -- </c4>

            If @PeriodLoc1 = 2 And @PeptideLength > 2
            Begin -- <c5>
                Set @PrimarySequence = Substring(@Peptide, @PeriodLoc1+1, @PeptideLength)
                Set @PrefixResidue = Substring(@Peptide, 1, @PeriodLoc1-1)
                Return 1
			End -- </c5>

            If @PeriodLoc1 = @PeptideLength - 1
            Begin -- <c6>
                Set @PrimarySequence = Substring(@Peptide, 1, @PeriodLoc1-1)
                Set @SuffixResidue = Substring(@Peptide, @PeriodLoc1+1, 1)
                Return 1
			End -- </c6>

        End -- </b>
    End -- </a>

    Return 0


GO
