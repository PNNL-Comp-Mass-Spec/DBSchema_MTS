SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SetPeptideProphetTaskCompleteMaster]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[SetPeptideProphetTaskCompleteMaster]
GO


CREATE PROCEDURE dbo.SetPeptideProphetTaskCompleteMaster
/****************************************************
**
**	Desc: 
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	07/05/2006
**
*****************************************************/
(
	@taskID int,
	@dbName varchar (128),
	@completionCode int = 0, -- 0->Success, 1->UpdateFailed, 2->ResultsFailed
	@message varchar(512) output
)
As
	set nocount on

	declare @myError int
	set @myError = 0

	set @message = ''

	declare @SPToExec varchar(255)
	
	---------------------------------------------------
	-- Call SetPeptideProphetTaskComplete in the given DB
	---------------------------------------------------
	
	set @SPToExec = '[' + @dbName + ']..SetPeptideProphetTaskComplete'

	exec @myError = @SPToExec @taskID, @completionCode, @message = @message output


	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

