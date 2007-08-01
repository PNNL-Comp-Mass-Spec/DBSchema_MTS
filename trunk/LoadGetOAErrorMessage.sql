/****** Object:  StoredProcedure [dbo].[LoadGetOAErrorMessage] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCedure LoadGetOAErrorMessage
/****************************************************
**
**	Desc: 
**        
**
**	Return values: 0: end of line not yet encountered
**
**	Parameters:
**
**		Auth: grk
**		Date: 8/25/2001
**    
*****************************************************/
    @object int,
    @hresult int,
    @message varchar(255) output
AS
	declare @mes varchar(255)
	DECLARE @output varchar(255)
	DECLARE @hrhex char(10)
	DECLARE @hr int
	DECLARE @source varchar(255)
	DECLARE @description varchar(255)

	EXEC @hr = sp_OAGetErrorInfo @object, @source OUT, @description OUT
	IF @hr = 0
	BEGIN
		set @output = '  Source: ' + @source
		set @mes = @output
		set @output = '  Description: ' + @description
		set @mes = @mes + @output
		set @message = @mes
	END
	ELSE
	BEGIN
	    set @message = '  sp_OAGetErrorInfo failed'
	END

	Return


GO
GRANT EXECUTE ON [dbo].[LoadGetOAErrorMessage] TO [DMS_SP_User]
GO
