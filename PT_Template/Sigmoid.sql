/****** Object:  UserDefinedFunction [dbo].[Sigmoid] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE FUNCTION dbo.Sigmoid
/***************************
** Sigmoid function
** 
** Auth:	EFS
** Date:	08/02/2004
**			10/28/2007 mem - Fixed overflow bug that occurred when (@coeff2-@param)/@coeff3 was too large
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
	Declare @Result float
	Set @Result = (@coeff2-@param)/@coeff3
	
	If @Result < 700
		Set @Result = @coeff1/(1+exp(@Result))
	Else
		Set @Result = 0
	
	Return @Result
END


GO
GRANT EXECUTE ON [dbo].[Sigmoid] TO [DMS_SP_User]
GO
