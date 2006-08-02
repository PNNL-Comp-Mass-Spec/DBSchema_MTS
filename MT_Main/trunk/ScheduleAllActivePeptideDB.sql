SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ScheduleAllActivePeptideDB]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ScheduleAllActivePeptideDB]
GO

CREATE PROCEDURE ScheduleAllActivePeptideDB
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
**			  8/10/2004 mem - Updated to set the PDB_Demand_Import to 1 for all active databases with a holdoff time of 24 hours
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
	-- Update databases in T_Peptide_Database_List that have a
	-- holdoff time of 24 hours
	-----------------------------------------------------------
	--
	UPDATE T_Peptide_Database_List
			SET PDB_Demand_Import = 1
	WHERE PDB_State In (2,5) AND PDB_Import_Holdoff = 24
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Could not update peptide database last import times'
		set @myError = 39
		goto Done
	end

	-----------------------------------------------------------
	-- log successful completion of master schedule process
	-----------------------------------------------------------
	
	set @message = 'Master PeptideDB Schedule Completed ' + convert(varchar(32), @myError)
	execute PostLogEntry 'Normal', @message, 'ScheduleAllActivePeptideDB'

Done:
	-----------------------------------------------------------
	-- 
	-----------------------------------------------------------
	--
	if @myError <> 0 
	begin
		set @message = 'Master PeptideDB Schedule Error ' + convert(varchar(32), @myError) + ' occurred'
		execute PostLogEntry 'Error', @message, 'ScheduleAllActivePeptideDB'
	end

	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[ScheduleAllActivePeptideDB]  TO [DMS_SP_User]
GO

