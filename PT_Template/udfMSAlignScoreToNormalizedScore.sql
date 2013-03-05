/****** Object:  UserDefinedFunction [dbo].[udfMSAlignScoreToNormalizedScore] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION dbo.udfMSAlignScoreToNormalizedScore
/****************************************************	
**	Converts MSAlign PValue to a normalized score
**  value that is comparable to XCorr
**
**	Auth:	mem
**	Date: 	12/03/2012
**  
****************************************************/
(
	@PValue real,
	@ChargeState smallint
)
RETURNS real
AS
BEGIN
	
	Declare @NormalizedScore real
	Declare @LogPValue float
	
	If @PValue Is Null
	Begin
		Set @NormalizedScore = 0
	End
	Else
	Begin
		If @PValue <= 1E-100
			Set @LogPValue = 100
		Else
			Set @LogPValue = -Log10(@PValue)
			
		-- Slope and intercept values are approximated by correlating -Log10(PValue) and XCorr using 
		--  MSAlign jobs 868891, 868892, 868893, and 868894 vs
		--  Sequest jobs 871078, 871079, 871080, and 871081
		-- in PT_Human_NCBI_A263

		If @ChargeState > 0
			Set @NormalizedScore = 0.2 * @LogPValue + 2.2
	
		
		If @NormalizedScore < 0
			Set @NormalizedScore = 0
	
	End
	
	RETURN  @NormalizedScore
END

GO
