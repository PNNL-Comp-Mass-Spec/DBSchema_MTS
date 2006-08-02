SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[JobComplete]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[JobComplete]
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

