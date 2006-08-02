SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[AddGANETUpdateTask]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[AddGANETUpdateTask]
GO


CREATE PROCEDURE dbo.AddGANETUpdateTask
/****************************************************
**
**	Desc: 
**		Adds a new entry to the T_GANET_Update_Task table
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**		Auth: grk
**		Date: 6/24/2003
**
**		Updated: 7/22/2003 by mem
**		Updated: 7/30/2003 by mem
**		Updated: 11/25/2003 by grk: expanded definition of pending task states
**		Updated: 04/08/2004 by mem: fixed some typos
**     
*****************************************************/
	@message varchar(255) output
AS
	Set NOCOUNT ON

	Declare @myError int
	Set @myError = 0

	Declare @myRowCount int
	Set @myRowCount = 0
	
	Set @message = ''


	---------------------------------------------------
	-- Are there any pending tasks already in table?
	---------------------------------------------------
	
	declare @hits int
	set @hits = 0

	SELECT @hits = COUNT(*)
	FROM         T_GANET_Update_Task
	WHERE Processing_State in (1, 2, 3)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error trying to check existing tasks'
		goto done
	end

	if @hits > 0
	begin
		set @message = 'Cannot add task when existing task is active'
		goto done
	end

	---------------------------------------------------
	-- Add new task
	---------------------------------------------------

	INSERT INTO T_GANET_Update_Task
		(Processing_State, Task_Created)
	VALUES
		(1, GETDATE())
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error inserting new entry in table'
		goto done
	end
	
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
Done:
RETURN @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

