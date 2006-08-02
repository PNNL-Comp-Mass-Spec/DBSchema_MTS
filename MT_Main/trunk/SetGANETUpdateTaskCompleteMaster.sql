SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SetGANETUpdateTaskCompleteMaster]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[SetGANETUpdateTaskCompleteMaster]
GO


CREATE PROCEDURE dbo.SetGANETUpdateTaskCompleteMaster

/****************************************************
**
**	Desc: 
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: grk
**		Date: 08/26/2003  
**			  06/28/2004 mem - Changed from @mtdbName to @dbName 
**			  11/23/2005 mem - Added brackets around @CurrentMTDB as needed to allow for DBs with dashes in the name
**
*****************************************************/
	@taskID int,
	@dbName varchar (128),
	@completionCode int = 0, -- 0->Success, 1->UpdateFailed, 2->ResultsFailed
	@message varchar(512) output
As
	set nocount on

	declare @myError int
	set @myError = 0

	set @message = ''

	declare @SPToExec varchar(255)
	
	---------------------------------------------------
	-- Call SetGANETUpdateTaskComplete in the given mtdb
	---------------------------------------------------
	
	set @SPToExec = '[' + @dbName + ']..SetGANETUpdateTaskComplete'

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

GRANT  EXECUTE  ON [dbo].[SetGANETUpdateTaskCompleteMaster]  TO [DMS_SP_User]
GO

