/****** Object:  UserDefinedFunction [dbo].[udfTotalPRMScoreToNormalizedScore] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

create FUNCTION udfTotalPRMScoreToNormalizedScore
/****************************************************	
**	Converts Inspect TotalPRMScore to a normalized score
**  value that is comparable to XCorr
**
**	Auth:	mem
**	Date: 	10/21/2008
**  
****************************************************/
(
	@TotalPRMScore real,
	@ChargeState smallint
)
RETURNS real
AS
BEGIN
	
	Declare @NormalizedScore real

	-- Slope and intercept values come from 14 QC Standards datasets
	--   searched by both Sequest and XTandem (see MT_Software_Q283)
	-- Dataset IDs are: 131264, 131437, 131869, 131861, 131896, 131837, 131840, 131883, 131451, 131430, 131870, 131918, 131862, 131892

	If @ChargeState = 1
		Set @NormalizedScore = 0.01297 * @TotalPRMScore + 1.18329
		
	If @ChargeState = 2
		Set @NormalizedScore = 0.02150 * @TotalPRMScore + 1.16114
	
	If @ChargeState >= 3 OR @ChargeState < 1
		Set @NormalizedScore = 0.03135 * @TotalPRMScore + 2.18849

	If @NormalizedScore < 0
		Set @NormalizedScore = 0

	RETURN  @NormalizedScore
END

GO
