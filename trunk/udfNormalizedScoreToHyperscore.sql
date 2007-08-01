/****** Object:  UserDefinedFunction [dbo].[udfNormalizedScoreToHyperscore] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION dbo.udfNormalizedScoreToHyperscore
/****************************************************	
**	Converts from normalized score to XTandem Hyperscore
**
**	Auth:	mem
**	Date: 	12/14/2005
**			01/27/2006 mem - Switched to simply multiplying by a slope value when converting from XCorr to Hyperscore
**  
****************************************************/
(
	@NormalizedScore real,
	@ChargeState smallint
)
RETURNS real
AS
BEGIN
	
	Declare @Hyperscore real
	
/*	
	-- Slope and intercept values from 19 QC Standards datasets, 
	-- searched by both Sequest and XTandem (see MT_Software_Q283)
	If @ChargeState = 1
		Set @Hyperscore = (@NormalizedScore - 0.544)/0.0653
		
	If @ChargeState = 2
		Set @Hyperscore = (@NormalizedScore - 1.3278)/0.0568
	
	If @ChargeState >= 3 OR @ChargeState < 1
		Set @Hyperscore = (@NormalizedScore - 1.2049)/0.0647
*/

	If @ChargeState = 1
		Set @Hyperscore = @NormalizedScore / 0.082
		
	If @ChargeState = 2
		Set @Hyperscore = @NormalizedScore / 0.085
	
	If @ChargeState >= 3 OR @ChargeState < 1
		Set @Hyperscore = @NormalizedScore  / 0.0874

	
	RETURN  @Hyperscore
END


GO
