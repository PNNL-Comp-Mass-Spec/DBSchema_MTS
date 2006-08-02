SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[udfHyperscoreToNormalizedScore]') and xtype in (N'FN', N'IF', N'TF'))
drop function [dbo].[udfHyperscoreToNormalizedScore]
GO


CREATE FUNCTION dbo.udfHyperscoreToNormalizedScore
/****************************************************	
**	Converts XTandem Hyperscore to a normalized score
**  value that is comparable to XCorr
**
**	Auth:	mem
**	Date: 	12/14/2005
**			01/27/2006 mem - Switched to simply multiplying by a slope value when converting from Hyperscore to XCorr
**  
****************************************************/
(
	@Hyperscore real,
	@ChargeState smallint
)
RETURNS real
AS
BEGIN
	
	Declare @NormalizedScore real

/*	
	-- Slope and intercept values from 19 QC Standards datasets, 
	-- searched by both Sequest and XTandem (see MT_Software_Q283)
	If @ChargeState = 1
		Set @NormalizedScore = 0.0653 * @Hyperscore + 0.544
		
	If @ChargeState = 2
		Set @NormalizedScore = 0.0568 * @Hyperscore + 1.3278
	
	If @ChargeState >= 3 OR @ChargeState < 1
		Set @NormalizedScore = 0.0647 * @Hyperscore + 1.2049
*/


	-- Slope values from 45 Human NAF datasets searched by both
	-- Sequest and XTandem (see MT_Human_P287 vs. MT_Human_X289)
	If @ChargeState = 1
		Set @NormalizedScore = 0.082 * @Hyperscore
		
	If @ChargeState = 2
		Set @NormalizedScore = 0.085 * @Hyperscore
	
	If @ChargeState >= 3 OR @ChargeState < 1
		Set @NormalizedScore = 0.0874 * @Hyperscore

	RETURN  @NormalizedScore
END


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

