/****** Object:  StoredProcedure [dbo].[ScheduleOneMassTagDB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE ScheduleOneMassTagDB
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
**		Date: 4/12/2004
**		      4/21/2004 grk - fixed reversed logic for @overwriteExisting
**			  6/01/2004 mem - Changed the Single MassTagDB Schedule Completed message to include the database name
**			  6/05/2004 mem - Now only posting an entry to T_Log_Entries if a DB is successfully scheduled
**			  8/28/2004 mem - Updated to set the MTL_Demand_Import = 1 for given MTDB; Removed the @overwriteExisting parameter
*****************************************************/
	@MTDBName varchar(128) = '',
	@message varchar(255) = '' output 
As
	set nocount on
	
	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	---------------------------------------------------
	-- validate mass tag DB name
	---------------------------------------------------
	--
	Declare @MTL_ID int
	set @MTL_ID = 0
	--
	SELECT  @MTL_ID = MTL_ID
	FROM MT_Main.dbo.T_MT_Database_List
	WHERE (MTL_Name = @MTDBName)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 or @myRowCount <> 1
	begin
		set @message = 'Could not resolve mass tag DB name: ' + @MTDBName
		Set @myError = 38
		goto Done
	end
	
	---------------------------------------------------
	-- Set MTL_Demand_Import to 1 for this MT DB
	---------------------------------------------------
	--
	UPDATE T_MT_Database_List
	SET MTL_Demand_Import = 1
	WHERE MTL_ID = @MTL_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Could not schedule MT DB for update: ' + @MTDBName
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
		set @message = 'Scheduled MassTagDB for update: ' + @MTDBName
		execute PostLogEntry 'Normal', @message, 'ScheduleOneMassTagDB'
	 end
	else
	 begin
		If len(@message) = 0
			set @message = 'Single MassTagDB Schedule Error ' + convert(varchar(32), @myError) + ' occurred: ' + @MTDBName
	 end

	return @myError

GO
GRANT EXECUTE ON [dbo].[ScheduleOneMassTagDB] TO [DMS_SP_User]
GO
