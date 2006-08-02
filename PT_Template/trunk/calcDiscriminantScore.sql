SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[calcDiscriminantScore]') and xtype in (N'FN', N'IF', N'TF'))
drop function [dbo].[calcDiscriminantScore]
GO


CREATE FUNCTION dbo.calcDiscriminantScore
/***************************
** Discriminant Function for Peptide Confidence calculation
** 
** Auth: EFS
** Date: 08-03-04
**
**		 09/08/2004 mem - Added check for situation where both predicted and observed NET are 0
**		 11/01/2004 mem - Updated value for @NETd to be 0.1 instead of 0.2 when @NETp and @NETo are 0
**		 07/06/2005 mem - Updated to group all @chargeState values >= 3 together
**
***************************/
(
	@Xcorr float, 
	@delCn float,			-- deltaCn2
	@delm float,
	@NETo float, 
	@NETp float, 
	@Rsp float, 
	@Xcrnk int, 
	@Xcratio float, 
	@chargeState int, 
	@LenSequence int, 
	@CleavageState int,
	@nmc int,
	@passFilt int, 
	@Mscore float
)
	RETURNS float 
AS  
BEGIN

	--some loal variables
	DECLARE @value_x FLOAT
	DECLARE @NETd FLOAT
	DECLARE @lnRsp FLOAT
	DECLARE @XcorrP FLOAT
	
	--calculate difference between predicted and observed NET
	--however, if @NETp and @NETo are both 0, then set @NETd to 0.1
	-- to indicate a large difference from the expected value
	If @NETp = 0 AND @NETo = 0
		set @NETd = 0.1
	Else
		set @NETd = abs(@NETp - @NETo)

	--get log of rank Sp
	set @lnRsp = log(@Rsp)
	--discriminant uses XCorr prime, not Xcorr
	set @XcorrP = dbo.GetXcorrP(@Xcorr,@LenSequence,@chargeState)
	
	If @MScore<3.0
	begin
	  set @Mscore=10
	end
	--different discriminant coeff for different CS
	-- the guts of the discriminant...
	If @chargeState=1  
	begin
		set @value_x = -0.36 + dbo.Sigmoid(@XcorrP, 0.735, 0.226 ,0.131) + 
		dbo.Sigmoid(@delm, -0.165, 0.626, 0.157) +
		dbo.Sigmoid(@delCn, 0.784,0.145, 0.063) +
		dbo.Sigmoid(@lnRsp, -0.396, 1.170, 0.226)  +
		dbo.Sigmoid(@NETd, -0.929, 0.045, 0.071) +
		dbo.Sigmoid(@Xcratio, 0.247, 1.03, 0.157) +
		dbo.Sigmoid(@Mscore, 0.603, 11.57, 0.36) +
		dbo.Sigmoid(@nmc, -0.657, 0.117, 0.204) +
		dbo.Sigmoid(@Xcrnk, -0.33, 1.26,.197) 
	
		If @CleavageState = 1
			set @value_x = @value_x + 0.417
		If @CleavageState = 2
			set @value_x = @value_x +0.99
	
		set @value_x = 2.11 * @value_x
	end
	If @chargeState=2
	begin
		set @value_x = -1.24 + dbo.Sigmoid(@XcorrP, 0.995, 0.382 ,0.030) + 
		dbo.Sigmoid(@delm, -0.157, 0.92, 0.208) +
		dbo.Sigmoid(@delCn, 0.967,0.103, 0.092) +
		dbo.Sigmoid(@lnRsp, -0.033, 1.184, 0.141)  +
		dbo.Sigmoid(@NETd, -0.98, 0.060, 0.060) +
		dbo.Sigmoid(@Xcratio, 0.040, 0.81, 0.057) +
		dbo.Sigmoid(@Mscore, 0.966, 11.36, 0.23) +
		dbo.Sigmoid(@nmc, -0.040, 0.103, 0.204) +
		dbo.Sigmoid(@Xcrnk, -0.102, 0.99,.197) 
	
		If @CleavageState = 1
			set @value_x = @value_x + 0.327
		If @CleavageState = 2
			set @value_x = @value_x +0.829
	
		set @value_x = 1.46 * @value_x
	end
	If @chargeState>=3
	begin
		set @value_x =-1.30 + dbo.Sigmoid(@XcorrP, 0.985, 0.345 ,0.036) + 
		dbo.Sigmoid(@delm, -0.232, 0.568, 0.312) +
		dbo.Sigmoid(@delCn, 0.945,0.103, 0.053) +
		dbo.Sigmoid(@lnRsp, -0.075, 1.837, 0.090)  +
		dbo.Sigmoid(@NETd, -0.997, 0.040, 0.090) +
		dbo.Sigmoid(@Xcratio, 0.02, 1.16, 0.06) +
		dbo.Sigmoid(@Mscore, 0.362, 13.1, 0.362) +
		dbo.Sigmoid(@nmc, -0.472, 0.162, 0.064) +
		dbo.Sigmoid(@Xcrnk, -0.204, 1.39,0.356) 
	
		If @CleavageState = 1
			set @value_x = @value_x + 0.29
		If @CleavageState = 2
			set @value_x = @value_x +0.94
	
		set @value_x = 1.89 * @value_x
	end

	return (@value_x)
END


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

