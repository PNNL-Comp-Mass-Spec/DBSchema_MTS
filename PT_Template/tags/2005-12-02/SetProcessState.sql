SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SetProcessState]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[SetProcessState]
GO



CREATE PROCedure SetProcessState
/****************************************************
**
**	Desc: Sets process state of analysis description
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	
**		Auth: grk
**		Date: 10/31/2001
**
**		Updated: 07/03/2004 by mem - Now updating the Process_State field
**    
*****************************************************/
	@Job int,
	@state int
As
	set nocount on

	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	UPDATE T_Analysis_Description 
	SET Process_State = @state, Last_Affected = GETDATE()
	WHERE (Job = @Job)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	return @myError



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

