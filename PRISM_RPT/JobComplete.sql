/****** Object:  StoredProcedure [dbo].[JobComplete] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE JobComplete
/****************************************************	
**  Desc: Marks an export job as complete.
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
	@jobkey as int,
	@filename as varchar(100)
)
AS

	declare @myError int
	set @myError = 0
	
	execute @myError = UpdateJobStatus @jobkey, 3, @filename
	RETURN @myError

GO
GRANT VIEW DEFINITION ON [dbo].[JobComplete] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[JobComplete] TO [MTS_DB_Lite] AS [dbo]
GO
