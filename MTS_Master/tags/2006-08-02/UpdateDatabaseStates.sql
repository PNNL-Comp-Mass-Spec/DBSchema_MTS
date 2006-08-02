SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UpdateDatabaseStates]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[UpdateDatabaseStates]
GO

CREATE Procedure dbo.UpdateDatabaseStates
/****************************************************
** 
**		Desc: Updates the State_ID column in the master DB list tables
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth:	mem
**		Date:	11/12/2004
**				12/05/2004 mem - Added @StateIgnoreList parameter and updated call to UpdateDatabaseStatesSingleTable
**				12/06/2004 mem - Removed Pogo from the @ServerFilter input parameter and switched to using V_Active_MTS_Servers
**				08/02/2005 mem - Updated to pass @LocalSchemaVersionField and @RemoteSchemaVersionField to UpdateDatabaseStatesSingleTable
**    
*****************************************************/
	@ServerFilter varchar(128) = '',				-- If supplied, then only examines the databases on the given Server
	@UpdateTableNames tinyint = 1,
	@DBCountUpdatedTotal int = 0 OUTPUT,
	@message varchar(255) = '' OUTPUT
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	-- Validate or clear the input/output parameters
	Set @ServerFilter = IsNull(@ServerFilter, '')
	Set @DBCountUpdatedTotal = 0
	Set @message = ''

	declare @result int
	declare @ProcessSingleServer tinyint
	
	If Len(@ServerFilter) > 0
		Set @ProcessSingleServer = 1
	Else
		Set @ProcessSingleServer = 0

	declare @Server varchar(128)
	declare @ServerID int

	declare @Continue int
	declare @processCount int			-- Count of servers processed
	declare @DBCountUpdated int
	
	declare @StateIgnoreList varchar(128)
	Set @StateIgnoreList = '15, 100'
	
	-----------------------------------------------------------
	-- Update the states for the entries in the MT, Peptide, and Protein tables,
	--  optionally filtering by server
	--
	-- Process each server in V_Active_MTS_Servers
	-----------------------------------------------------------
	--
	set @processCount = 0
	set @DBCountUpdated = 0
	
	set @ServerID = -1
	set @Continue = 1
	--	
	While @Continue > 0 and @myError = 0
	Begin -- <A>

		SELECT TOP 1
			@ServerID = Server_ID,
			@Server = Server_Name
		FROM  V_Active_MTS_Servers
		WHERE Server_ID > @ServerID
		ORDER BY Server_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Could not get next entry from V_Active_MTS_Servers'
			set @myError = 50001
			goto Done
		end
		Set @continue = @myRowCount

		If @continue > 0 And (@ProcessSingleServer = 0 Or Lower(@Server) = Lower(@ServerFilter))
		Begin -- <B>

			-- Update the four tracking DBs for the given server
			
			Exec @result = UpdateDatabaseStatesSingleTable	@ServerID, @UpdateTableNames,
															'T_MTS_MT_DBs', 'MT_DB_ID', 'MT_DB_Name', 'State_ID', 'DB_Schema_Version',
															'T_MT_Database_List', 'MTL_ID', 'MTL_Name', 'MTL_State', 'MTL_DB_Schema_Version',
															@RemoteStateIgnoreList = @StateIgnoreList,
															@DBCountUpdated = @DBCountUpdated OUTPUT, @message = @message OUTPUT
			Set @DBCountUpdatedTotal = @DBCountUpdatedTotal + @DBCountUpdated
			
			if @result <> 0
			Begin
				set @myError = 50002
				goto Done
			End
			
			Exec @result = UpdateDatabaseStatesSingleTable	@ServerID, @UpdateTableNames,
															'T_MTS_Peptide_DBs', 'Peptide_DB_ID', 'Peptide_DB_Name', 'State_ID', 'DB_Schema_Version',
															'T_Peptide_Database_List', 'PDB_ID', 'PDB_Name', 'PDB_State', 'PDB_DB_Schema_Version',
															@RemoteStateIgnoreList = @StateIgnoreList,
															@DBCountUpdated = @DBCountUpdated OUTPUT, @message = @message OUTPUT
			Set @DBCountUpdatedTotal = @DBCountUpdatedTotal + @DBCountUpdated

			Exec @result = UpdateDatabaseStatesSingleTable	@ServerID, @UpdateTableNames,
															'T_MTS_Protein_DBs', 'Protein_DB_ID', 'Protein_DB_Name', 'State_ID', 'DB_Schema_Version',
															'T_ORF_Database_List', 'ODB_ID', 'ODB_Name', 'ODB_State', 'ODB_DB_Schema_Version',
															@RemoteStateIgnoreList = @StateIgnoreList,
															@DBCountUpdated = @DBCountUpdated OUTPUT, @message = @message OUTPUT
			Set @DBCountUpdatedTotal = @DBCountUpdatedTotal + @DBCountUpdated

/*
**	UMC DB Updating is disabled for now
**
**			Exec @result = UpdateDatabaseStatesSingleTable	@ServerID, @UpdateTableNames,
**															'T_MTS_UMC_DBs', 'UMC_DB_ID', 'UMC_DB_Name', 'State_ID', 'DB_Schema_Version',
**															'T_UMC_Database_List', 'UDB_ID', 'UDB_Name', 'UDB_State', 'UDB_DB_Schema_Version',
**															@RemoteStateIgnoreList = @StateIgnoreList,
**															@DBCountUpdated = @DBCountUpdated OUTPUT, @message = @message OUTPUT
**			Set @DBCountUpdatedTotal = @DBCountUpdatedTotal + @DBCountUpdated
*/			

/*
**	QC Trends DB Updating is disabled for now
**
**			Exec @result = UpdateDatabaseStatesSingleTable	@ServerID, @UpdateTableNames,
**															'T_MTS_QCT_DBs', 'QCT_DB_ID', 'QCT_DB_Name', 'State_ID', 'DB_Schema_Version',
**															'T_QCT_Database_List', 'UDB_ID', 'UDB_Name', 'UDB_State', 'UDB_DB_Schema_Version',
**															@RemoteStateIgnoreList = @StateIgnoreList,
**															@DBCountUpdated = @DBCountUpdated OUTPUT, @message = @message OUTPUT
**			Set @DBCountUpdatedTotal = @DBCountUpdatedTotal + @DBCountUpdated
*/			

			Set @processCount = @processCount + 1
			
		End -- </B>
			
	End -- </A>
	
Done:
	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--
	

	if @myError <> 0
	begin
		If Len(@message) = 0
			set @message = 'Error updating DB states on local/remote servers; Error code: ' + convert(varchar(32), @myError)

		Exec PostLogEntry 'Error', @message, 'UpdateDatabaseStates'
	end

	Declare @LogMessage varchar(256)
	Set @LogMessage = 'DB states updated for ' + Convert(varchar(9), @DBCountUpdatedTotal) + ' databases on ' + Convert(varchar(9), @processCount) + ' servers'

	if @DBCountUpdatedTotal > 0 
		Exec PostLogEntry 'Normal', @LogMessage, 'UpdateDatabaseStates'
	
	if Len(@message) = 0
		Set @message = @LogMessage

	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[UpdateDatabaseStates]  TO [MTUser]
GO

