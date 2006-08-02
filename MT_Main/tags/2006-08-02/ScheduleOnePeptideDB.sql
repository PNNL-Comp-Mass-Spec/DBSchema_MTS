SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ScheduleOnePeptideDB]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ScheduleOnePeptideDB]
GO

CREATE procedure ScheduleOnePeptideDB
/****************************************************
** 
**		Desc: 
**      Will schedule the given DB for update.
**
**      Normally requires the DB to be in an active state
**      and not be scheduled for update or in process of update.
**      These checks can be overriden by @overwriteExisting.
**		
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth: grk
**		Date: 4/19/2004
**		      4/21/2004 grk - fixed reversed logic for @overwriteExisting
**			  6/01/2004 mem - Changed the Single Peptide DB Schedule Completed message to include the database name
**			  6/05/2004 mem - Now only posting an entry to T_Log_Entries if a DB is successfully scheduled
**			  8/11/2004 mem - Updated to set the PDB_Demand_Import = 1 for given peptide DB; Removed the @overwriteExisting parameter
*****************************************************/
	@peptideDBName varchar(128) = '',
	@message varchar(255) = '' output
As
	set nocount on
	
	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	---------------------------------------------------
	-- validate Peptide DB name
	---------------------------------------------------
	--
	Declare @PDB_ID int
	set @PDB_ID = 0
	--
	SELECT  @PDB_ID = PDB_ID
	FROM MT_Main.dbo.T_Peptide_Database_List
	WHERE (PDB_Name = @peptideDBName)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 or @myRowCount <> 1
	begin
		set @message = 'Could not resolve peptide DB name: ' + @peptideDBName
		Set @myError = 38
		goto Done
	end
	
	---------------------------------------------------
	-- Set PDB_Demand_Import to 1 for this peptide DB
	---------------------------------------------------
	--
	UPDATE T_Peptide_Database_List
	SET PDB_Demand_Import = 1
	WHERE PDB_ID = @PDB_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Could not schedule peptide DB for update: ' + @peptideDBName
		set @myError = 42
		goto Done
	end
	
Done:
	-----------------------------------------------------------
	-- 
	-----------------------------------------------------------
	--
	if @myError = 0 
	 begin
		set @message = 'Scheduled PeptideDB for update: ' + @peptideDBName
		execute PostLogEntry 'Normal', @message, 'ScheduleOnePeptideDB'
	 end
	else
	 begin
		If len(@message) = 0
			set @message = 'Single PeptideDB Schedule Error ' + convert(varchar(32), @myError) + ' occurred: ' + @peptideDBName
	 end

	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[ScheduleOnePeptideDB]  TO [DMS_SP_User]
GO

