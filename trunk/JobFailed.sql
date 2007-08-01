/****** Object:  StoredProcedure [dbo].[JobFailed] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE JobFailed
/****************************************************	
**  Desc: Marks an export job as failed.
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: The jobkey is the record key.
**
**  Auth: jee
**	Date: 07/01/2004
**
****************************************************/
(
	@jobkey as int
)
AS

	declare @myError int
	set @myError = 0
	
	execute @myError = UpdateJobStatus @jobkey, 4
	RETURN @myError

GO
