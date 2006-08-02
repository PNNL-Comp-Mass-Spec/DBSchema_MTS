SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetNextProcessState]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetNextProcessState]
GO



CREATE PROCedure dbo.GetNextProcessState
/****************************************************
**
**	Desc: 
**		Determines the next highest ID in T_Process_State
**
**		Returns the state
**
**	Parameters:
**
**		Auth: mem
**		Date: 07/03/2004
**    
*****************************************************/
	@ProcessState int,
	@NextProcessStateOnError int = -1
AS
	Set NoCount On
	
	Declare @NextProcessState int
	
	Set @NextProcessState = @NextProcessStateOnError
	
	SELECT TOP 1 @NextProcessState = ID
	FROM T_Process_State
	WHERE ID > @ProcessState
	ORDER BY ID
	
	RETURN  @NextProcessState


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

