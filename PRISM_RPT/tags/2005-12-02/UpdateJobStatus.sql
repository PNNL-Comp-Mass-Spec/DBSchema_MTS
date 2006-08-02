SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UpdateJobStatus]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[UpdateJobStatus]
GO

CREATE PROCEDURE UpdateJobStatus
/****************************************************	
**  Desc: Updates the status for a job in T_QR_Export_Job
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: jobkey, statuskey, and filename
**
**  Auth: jee
**	Date: 07/01/2004
**
****************************************************/
(
	@jobkey as int,
	@statuskey as int OUTPUT,
	@filename varchar(100) = 'None'
)
AS
	-- Do not use this stored procedure from code.
	-- Use the JobComplete or JobFailed procedures instead.
	--
	-- This procedure changes the status of an export
	--		job and updates the last modified date time stamp.
	-- The jobkey is the record key.
	-- The statuskey is a key into the T_Status table and represents:
	--		1 = new
	--		2 = working
	--		3 = complete
	--		4 = failed
	--		5 = paused

	declare @dt as datetime
	declare @result as varchar(256)
	declare @myError int
	declare @rows int
	set @dt = getdate()
	set @myError = 0
	if @filename = 'None' 
	begin
		set @result = @filename
	end
	else
	begin
		set @result = '<A HREF="' + @filename + '">' + @filename +'</A>'
	end
	
	UPDATE    T_QR_Export_Job
	SET              modified = @dt, statuskey = @statuskey, result = @result
	WHERE     (jobkey = @jobkey)
	
	SELECT @myError = @@error, @rows = @@rowcount 

	if @rows <> 1 or @myError <> 0
	begin
		/* Update failed */
		set @myError = 52002
	end
	RETURN @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

