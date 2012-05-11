/****** Object:  UserDefinedFunction [dbo].[udfMSGFDBScoreToNormalizedScore] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION dbo.udfMSGFDBScoreToNormalizedScore
/****************************************************	
**	Converts MSGFDB MSGFScore to a normalized score
**  value that is comparable to XCorr
**
**	Auth:	mem
**	Date: 	08/23/2011
**  
****************************************************/
(
	@MSGFScore real,
	@ChargeState smallint
)
RETURNS real
AS
BEGIN
	
	Declare @NormalizedScore real

	-- Slope and intercept values come from the comparison of job 737085 to job 736317
	-- Dataset is QC_Shew_11_03_0pt5_10uL_18Aug11_Cougar_11-05-36

	If @ChargeState = 1
		Set @NormalizedScore = 0.0197 * @MSGFScore + 0.75
		
	If @ChargeState = 2
		Set @NormalizedScore = 0.0165 * @MSGFScore + 1.3
	
	If @ChargeState >= 3 OR @ChargeState < 1
		Set @NormalizedScore = 0.0267 * @MSGFScore + 1

	If @NormalizedScore < 0
		Set @NormalizedScore = 0

	RETURN  @NormalizedScore
END


GO
