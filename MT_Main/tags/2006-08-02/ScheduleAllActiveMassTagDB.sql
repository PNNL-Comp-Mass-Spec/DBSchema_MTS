SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ScheduleAllActiveMassTagDB]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ScheduleAllActiveMassTagDB]
GO

CREATE PROCEDURE ScheduleAllActiveMassTagDB
/****************************************************
** 
**		Desc: 
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth: grk
**		Date: 4/12/2004
**			  8/28/2004 mem - Updated to set the MTL_Demand_Import to 1 for all active databases with a holdoff time of 24 hours
**    
*****************************************************/
As
	set nocount on
	
	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0

	declare @result int
	
	declare @message varchar(255)

	-----------------------------------------------------------
	-- Update databases in T_MT_Database_List that have a
	-- holdoff time of 24 hours
	-----------------------------------------------------------
	--
	UPDATE T_MT_Database_List
			SET MTL_Demand_Import = 1
	WHERE MTL_State In (2,5) AND MTL_Import_Holdoff = 24
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Could not update MT database last import times'
		set @myError = 39
		goto Done
	end
		
	-----------------------------------------------------------
	-- log successful completion of Master MassTagDB Schedule process
	-----------------------------------------------------------
	
	set @message = 'Master MassTagDB Schedule Completed ' + convert(varchar(32), @myError)
	execute PostLogEntry 'Normal', @message, 'ScheduleAllActiveMassTagDB'

Done:
	-----------------------------------------------------------
	-- 
	-----------------------------------------------------------
	--
	if @myError <> 0 
	begin
		set @message = 'Master MassTagDB Schedule Error ' + convert(varchar(32), @myError) + ' occurred'
		execute PostLogEntry 'Error', @message, 'ScheduleAllActiveMassTagDB'
	end

	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[ScheduleAllActiveMassTagDB]  TO [DMS_SP_User]
GO

