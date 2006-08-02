SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[WebQRJobs]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[WebQRJobs]
GO

create PROCEDURE WebQRJobs
/****************************************************	
**  Desc: Retrieves list of QR Export jobs
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: Status message output
**
**  Auth: jee
**	Date: 07/01/2004
**
****************************************************/
	@message varchar(512) = '' output
AS
	declare @result int
	
	set @message = ''
	set @result = 0

	SELECT     *
	FROM         V_QR_Export_Job

	SELECT @result = @@error
	--
	if @result <> 0 
	begin
		set @message = 'Select failed'
	end

	RETURN @result

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[WebQRJobs]  TO [DMS_SP_User]
GO

