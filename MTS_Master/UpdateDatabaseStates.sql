/****** Object:  StoredProcedure [dbo].[UpdateDatabaseStates] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure dbo.UpdateDatabaseStates
/****************************************************
** 
**	Desc:	Updates the State_ID column in the master DB list tables
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	11/12/2004
**			12/05/2004 mem - Added @StateIgnoreList parameter and updated call to UpdateDatabaseStatesSingleTable
**			12/06/2004 mem - Removed Pogo from the @ServerFilter input parameter and switched to using V_Active_MTS_Servers
**			08/02/2005 mem - Updated to pass @LocalSchemaVersionField and @RemoteSchemaVersionField to UpdateDatabaseStatesSingleTable
**			08/30/2006 mem - Updated the log message
**			06/25/2008 mem - Added parameter @StateIgnoreList
**			04/20/2009 mem - Updated @StateIgnoreList to be '15,100'
**			02/05/2010 mem - Now sending @RemoteDescriptionField, @RemoteOrganismField, @RemoteCampaignField,and @PreviewSql to UpdateDatabaseStatesSingleTable
**			10/18/2011 mem - Now calling UpdateDatabaseStatesForOfflineDBs to auto-mark databases as deleted if their Last_Online date is more than 30 days ago yet their state is less than 15
**    
*****************************************************/
(
	@ServerFilter varchar(128) = '',				-- If supplied, then only examines the databases on the given Server
	@UpdateTableNames tinyint = 1,
	@DBCountUpdatedTotal int = 0 OUTPUT,
	@message varchar(255) = '' OUTPUT,
	@StateIgnoreList varchar(128) = '15,100',
	@PreviewSql tinyint = 0
)
As	
	Set nocount on
	
	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	-- Validate or clear the input/output parameters
	Set @ServerFilter = IsNull(@ServerFilter, '')
	Set @DBCountUpdatedTotal = 0
	Set @message = ''

	Declare @result int
	Declare @ProcessSingleServer tinyint
	
	If Len(@ServerFilter) > 0
		Set @ProcessSingleServer = 1
	Else
		Set @ProcessSingleServer = 0

	Declare @Server varchar(128)
	Declare @ServerID int

	Declare @Continue int
	Declare @processCount int			-- Count of servers processed
	Declare @DBCountUpdated int
	
	-----------------------------------------------------------
	-- Update the states for the entries in the MT, Peptide, and Protein tables,
	--  optionally filtering by server
	--
	-- Process each server in V_Active_MTS_Servers
	-----------------------------------------------------------
	--
	Set @processCount = 0
	Set @DBCountUpdated = 0
	
	Set @ServerID = -1
	Set @Continue = 1
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
		If @myError <> 0 
		Begin
			Set @message = 'Could not get next entry from V_Active_MTS_Servers'
			Set @myError = 50001
			Goto Done
		End
		Set @continue = @myRowCount

		If @continue > 0 And (@ProcessSingleServer = 0 Or Lower(@Server) = Lower(@ServerFilter))
		Begin -- <B>

			-- Update the four tracking DBs for the given server
			
			Exec @result = UpdateDatabaseStatesSingleTable	@ServerID, @UpdateTableNames,
															'T_MTS_MT_DBs', 'MT_DB_ID', 'MT_DB_Name', 'State_ID', 'DB_Schema_Version',
															'T_MT_Database_List', 'MTL_ID', 'MTL_Name', 'MTL_State', 'MTL_DB_Schema_Version',
															@RemoteDescriptionField = 'MTL_Description',
															@RemoteOrganismField = 'MTL_Organism',
															@RemoteCampaignField = 'MTL_Campaign',
															@PreviewSql=@PreviewSql,
															@RemoteStateIgnoreList = @StateIgnoreList,
															@DBCountUpdated = @DBCountUpdated OUTPUT, 
															@message = @message OUTPUT
															
			Set @DBCountUpdatedTotal = @DBCountUpdatedTotal + @DBCountUpdated
			
			If @result <> 0
			Begin
				Set @myError = 50002
				Goto Done
			End
			
			Exec @result = UpdateDatabaseStatesSingleTable	@ServerID, @UpdateTableNames,
															'T_MTS_Peptide_DBs', 'Peptide_DB_ID', 'Peptide_DB_Name', 'State_ID', 'DB_Schema_Version',
															'T_Peptide_Database_List', 'PDB_ID', 'PDB_Name', 'PDB_State', 'PDB_DB_Schema_Version',
															@RemoteDescriptionField = 'PDB_Description',
															@RemoteOrganismField = 'PDB_Organism',
															@RemoteCampaignField = '',
															@PreviewSql=@PreviewSql,
															@RemoteStateIgnoreList = @StateIgnoreList,
															@DBCountUpdated = @DBCountUpdated OUTPUT, 
															@message = @message OUTPUT
															
			Set @DBCountUpdatedTotal = @DBCountUpdatedTotal + @DBCountUpdated

			Exec @result = UpdateDatabaseStatesSingleTable	@ServerID, @UpdateTableNames,
															'T_MTS_Protein_DBs', 'Protein_DB_ID', 'Protein_DB_Name', 'State_ID', 'DB_Schema_Version',
															'T_ORF_Database_List', 'ODB_ID', 'ODB_Name', 'ODB_State', 'ODB_DB_Schema_Version',
															@RemoteDescriptionField = '',
															@RemoteOrganismField = '',
															@RemoteCampaignField = '',
															@PreviewSql=@PreviewSql,
															@RemoteStateIgnoreList = @StateIgnoreList,
															@DBCountUpdated = @DBCountUpdated OUTPUT, 
															@message = @message OUTPUT
															
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


	-- Mark MT databases as deleted (state 100) if they have been offline for over 30 days
	--		
	exec UpdateDatabaseStatesForOfflineDBs 'T_MTS_MT_DBs', 'MT', @InfoOnly=0

	-- Mark PT databases as deleted (state 100) if they have been offline for over 30 days
	--
	exec UpdateDatabaseStatesForOfflineDBs 'T_MTS_Peptide_DBs', 'PT', @InfoOnly=0

	
Done:
	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--

	If @myError <> 0
	Begin
		If Len(@message) = 0
			Set @message = 'Error updating DB states on local/remote servers; Error code: ' + convert(varchar(32), @myError)

		Exec PostLogEntry 'Error', @message, 'UpdateDatabaseStates'
	End

	Declare @LogMessage varchar(256)
	Set @LogMessage = 'DB states updated for ' + Convert(varchar(9), @DBCountUpdatedTotal)
	If @DBCountUpdatedTotal = 1
		Set @LogMessage = @LogMessage + ' database'
	Else
		Set @LogMessage = @LogMessage + ' databases'
	--
	Set @LogMessage = @LogMessage + ' on ' + Convert(varchar(9), @processCount) + ' servers'

	If @DBCountUpdatedTotal > 0 
		Exec PostLogEntry 'Normal', @LogMessage, 'UpdateDatabaseStates'
	
	If Len(@message) = 0
		Set @message = @LogMessage

	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[UpdateDatabaseStates] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateDatabaseStates] TO [MTS_DB_Lite] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[UpdateDatabaseStates] TO [MTUser] AS [dbo]
GO
