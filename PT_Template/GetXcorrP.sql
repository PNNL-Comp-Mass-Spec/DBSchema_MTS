/****** Object:  UserDefinedFunction [dbo].[GetXcorrP] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE FUNCTION GetXcorrP
/***************************
** Calculates Xcorr prime for discriminant function
** The purpose of this is get a length independdnt value for Xcorr
** 
** Auth:	EFS
** Date:	08/03/2004
**			07/06/2005 mem - Updated to group all @chargeState values >= 3 together
**			10/21/2008 mem - Updated to handle XCorr values that are 0 or negative
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
	
	If @Xcorr <=0
		set @ans = -10
	Else
	Begin
		If @chargeState = 1 
			set @ans =  log(@Xcorr)/log(2 * @length)
		If @chargeState = 2
			set @ans =  log(@Xcorr)/log(2 * @length)
		If @chargeState >= 3
			set @ans =  log(@Xcorr)/log(4 * @length)
	End
	
	return @ans

END

GO
