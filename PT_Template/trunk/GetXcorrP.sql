/****** Object:  UserDefinedFunction [dbo].[GetXcorrP] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION dbo.GetXcorrP
/***************************
** Calculates Xcorr prime for discriminant function
** The purpose of this is get a length independdnt value for Xcorr
** 
** Auth: EFS
** Date: 08/03/2004
**		 07/06/2005 mem - Updated to group all @chargeState values >= 3 together
** 
***************************/
(
	@Xcorr float, 
	@length int,
	@chargeState int
)  
	RETURNS float 
AS
BEGIN 
	
	declare @ans float
	
	If @chargeState = 1 
		set @ans =  log(@Xcorr)/log(2 * @length)
	If @chargeState = 2
		set @ans =  log(@Xcorr)/log(2 * @length)
	If @chargeState >= 3
		set @ans =  log(@Xcorr)/log(4 * @length)

	return @ans

END


GO
