/****** Object:  UserDefinedFunction [dbo].[Sigmoid] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION dbo.Sigmoid
/***************************
** Sigmoid function
** 
** Auth: EFS
** Date: 08-02-04
** 
***************************/
(
	@param float, 
	@coeff1 float, 
	@coeff2 float, 
	@coeff3 float
)
	RETURNS float
AS  
BEGIN 
	Return @coeff1/(1+exp((@coeff2-@param)/@coeff3))
END

GO
GRANT EXECUTE ON [dbo].[Sigmoid] TO [DMS_SP_User]
GO
