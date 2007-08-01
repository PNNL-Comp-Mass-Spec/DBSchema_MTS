/****** Object:  StoredProcedure [dbo].[SendMail] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure SendMail
	(
		@server varchar(100),
		@toAdr varchar(100),
		@subject varchar(100),
		@message varchar(2048) 
	)
As
	/* set nocount on */
	declare @mailerObj int
	declare @hr int
	declare @badNews varchar(255)
	declare @fromAdr varchar(100)
	
	-- Create object
	--
	exec @hr = sp_OACreate 'HTMLMailer.SimpleMailer', @mailerObj output
	if @hr <> 0
	begin
		exec LoadGetOAErrorMessage @mailerObj, @hr, @badNews output
		return -1
	end
	
	-- Create 'from' address
	--
	set @fromAdr = 'SQLServer@PRISM_MTS_' + db_name()
	
	-- Send mail
	--
	exec @hr = sp_OAMethod @mailerObj, 'SendMail', NULL, @server, @toAdr, @subject, @message, @fromAdr
	if @hr <> 0
	begin
		exec LoadGetOAErrorMessage @mailerObj, @hr, @badNews output
	end
	
	-- Destroy object
	--
	exec @hr = sp_OADestroy @mailerObj
	if @hr <> 0
	begin
		exec LoadGetOAErrorMessage @mailerObj, @hr, @badNews output
		return -3
	end
	return 0

GO
GRANT EXECUTE ON [dbo].[SendMail] TO [DMS_SP_User]
GO
