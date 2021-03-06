/****** Object:  StoredProcedure [dbo].[SetProcessState] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE SetProcessState
/****************************************************
**
**	Desc: Sets process state of analysis description
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	
**	Auth:	grk
**	Date:	10/31/2001
**			07/03/2004 by mem - Now updating the Last_Affected field
**    
*****************************************************/
(
	@Job int,
	@state int
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	UPDATE T_Analysis_Description 
	SET Process_State = @state, Last_Affected = GETDATE()
	WHERE (Job = @Job)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[SetProcessState] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[SetProcessState] TO [MTS_DB_Lite] AS [dbo]
GO
