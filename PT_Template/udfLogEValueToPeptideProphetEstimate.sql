/****** Object:  UserDefinedFunction [dbo].[udfLogEValueToPeptideProphetEstimate] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION dbo.udfLogEValueToPeptideProphetEstimate
/****************************************************	
**	Converts XTandem Log_EValue to a pseudo-peptide prophet value
**
**	Auth:	mem
**	Date: 	02/18/2011
**  
****************************************************/
(
	@LogEValue real
)
RETURNS real
AS
BEGIN
	
	Declare @PseudoPeptideProphet real = 0.97

	If @LogEValue <= -7 Set @PseudoPeptideProphet = 1
	Else 
	If @LogEValue <= -6 Set @PseudoPeptideProphet = 0.9999
	Else 
	If @LogEValue <= -5 Set @PseudoPeptideProphet = 0.999
	Else 
	If @LogEValue <= -4 Set @PseudoPeptideProphet = 0.995
	Else 
	If @LogEValue <= -3 Set @PseudoPeptideProphet = 0.99
	Else 
	If @LogEValue <= -2 Set @PseudoPeptideProphet = 0.985
	Else 
	If @LogEValue <= -1.25 Set @PseudoPeptideProphet = 0.98
	Else 
	If @LogEValue <= -0.66 Set @PseudoPeptideProphet = 0.9775
	Else 
	If @LogEValue <= -0.33 Set @PseudoPeptideProphet = 0.975
		
	RETURN  @PseudoPeptideProphet
END


GO
