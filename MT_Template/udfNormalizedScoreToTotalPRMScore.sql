/****** Object:  UserDefinedFunction [dbo].[udfNormalizedScoreToTotalPRMScore] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

create FUNCTION udfNormalizedScoreToTotalPRMScore
/****************************************************	
**	Converts from normalized score to Inspect TotalPRMScore
**
**	Auth:	mem
**	Date: 	10/21/2008
**  
****************************************************/
(
	@NormalizedScore real,
	@ChargeState smallint
)
RETURNS real
AS
BEGIN
	
	Declare @TotalPRMScore real

	-- Slope and intercept values come from 14 QC Standards datasets
	--   searched by both Sequest and XTandem (see MT_Software_Q283)
	-- Dataset IDs are: 131264, 131437, 131869, 131861, 131896, 131837, 131840, 131883, 131451, 131430, 131870, 131918, 131862, 131892

	If @ChargeState = 1
		Set @TotalPRMScore = (@NormalizedScore - 1.18329)/0.01297
		
	If @ChargeState = 2
		Set @TotalPRMScore = (@NormalizedScore - 1.16114)/0.02150
	
	If @ChargeState >= 3 OR @ChargeState < 1
		Set @TotalPRMScore = (@NormalizedScore - 2.18849)/0.03135

	
	RETURN  @TotalPRMScore
END

GO
