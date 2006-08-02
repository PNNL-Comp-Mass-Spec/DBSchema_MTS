SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetXcorrP]') and xtype in (N'FN', N'IF', N'TF'))
drop function [dbo].[GetXcorrP]
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

