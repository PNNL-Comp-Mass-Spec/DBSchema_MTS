SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UpdateUserPermissions]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[UpdateUserPermissions]
GO


CREATE PROCEDURE dbo.UpdateUserPermissions
/****************************************************
**
**	Desc: Updates user permissions in the current DB
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	12/13/2004
**			01/27/2005 mem - Added MTS_DB_Dev and MTS_DB_Lite
**			05/03/2006 mem - Updated to Sql Server 2005 syntax
**			06/08/2006 mem - Added table and SP permissions required for the Master_Sequences database
**    
*****************************************************/
AS
	Set NoCount On

	if exists (select * from sys.schemas where name = 'MTUser')
		drop schema MTUser
	if exists (select * from sys.sysusers where name = 'MTUser')
		drop user MTUser
	create user MTUser for login MTUser
	exec sp_addrolemember 'db_datareader', 'MTUser'
	exec sp_addrolemember 'DMS_SP_User', 'MTUser'
		
	if exists (select * from sys.schemas where name = 'MTAdmin')
		drop schema MTAdmin
	if exists (select * from sys.sysusers where name = 'MTAdmin')
		drop user MTAdmin
	create user MTAdmin for login MTAdmin
	exec sp_addrolemember 'db_datareader', 'MTAdmin'
	exec sp_addrolemember 'db_datawriter', 'MTAdmin'
	exec sp_addrolemember 'DMS_SP_User', 'MTAdmin'

	if exists (select * from sys.schemas where name = 'MTS_DB_Dev')
		drop schema MTS_DB_Dev
	if exists (select * from sys.sysusers where name = 'MTS_DB_Dev')
		drop user MTS_DB_Dev
	create user MTS_DB_Dev for login [daffy\MTS_DB_Dev]
	exec sp_addrolemember 'db_owner', 'MTS_DB_DEV'
	exec sp_addrolemember 'db_ddladmin', 'MTS_DB_DEV'
	exec sp_addrolemember 'db_backupoperator', 'MTS_DB_DEV'
	exec sp_addrolemember 'db_datareader', 'MTS_DB_DEV'
	exec sp_addrolemember 'db_datawriter', 'MTS_DB_DEV'
	exec sp_addrolemember 'DMS_SP_User', 'MTS_DB_DEV'

	if exists (select * from sys.schemas where name = 'MTS_DB_Lite')
		drop schema MTS_DB_Lite
	if exists (select * from sys.sysusers where name = 'MTS_DB_Lite')
		drop user MTS_DB_Lite
	create user MTS_DB_Lite for login [daffy\MTS_DB_Lite]
	exec sp_addrolemember 'db_datareader', 'MTS_DB_Lite'
	exec sp_addrolemember 'db_datawriter', 'MTS_DB_Lite'
	exec sp_addrolemember 'DMS_SP_User', 'MTS_DB_Lite'

	GRANT INSERT ON [dbo].[T_Sequence] TO [DMS_SP_User]
	GRANT INSERT ON [dbo].[T_Sequence] TO [MTUser]
	
	GRANT UPDATE ON [dbo].[T_Sequence] ([Seq_ID]) TO [DMS_SP_User]
	GRANT UPDATE ON [dbo].[T_Sequence] ([Seq_ID]) TO [MTUser]
	
	GRANT UPDATE ON [dbo].[T_Sequence] ([GANET_Predicted]) TO [DMS_SP_User]
	GRANT UPDATE ON [dbo].[T_Sequence] ([GANET_Predicted]) TO [MTUser]
	
	GRANT UPDATE ON [dbo].[T_Sequence] ([Last_Affected]) TO [DMS_SP_User]
	GRANT UPDATE ON [dbo].[T_Sequence] ([Last_Affected]) TO [MTUser]
	
	GRANT INSERT ON [dbo].[T_Log_Entries] TO [DMS_SP_User]
	
	GRANT INSERT ON [dbo].[T_Param_File_Mods_Cache] TO [DMS_SP_User]
	GRANT UPDATE ON [dbo].[T_Param_File_Mods_Cache] TO [DMS_SP_User]
	
	GRANT INSERT ON [dbo].[T_Seq_to_Archived_Protein_Collection_File_Map] TO [DMS_SP_User]
	
	GRANT INSERT ON [dbo].[T_Seq_Map] TO [DMS_SP_User]
	
	GRANT INSERT ON [dbo].[T_Mod_Descriptors] TO [DMS_SP_User]
	
	
	GRANT EXECUTE ON [dbo].[NextField] TO [DMS_SP_User]
	
	GRANT EXECUTE ON [dbo].[CreateTempCandidateSequenceTables] TO [DMS_SP_User]
	GRANT EXECUTE ON [dbo].[CreateTempSequenceTables] TO [DMS_SP_User]
	GRANT EXECUTE ON [dbo].[CreateTempPNETTables] TO [DMS_SP_User]
	
	GRANT EXECUTE ON [dbo].[UpdatePNETDataForSequences] TO [DMS_SP_User]
	
	GRANT EXECUTE ON [dbo].[DropTempSequenceTables] TO [DMS_SP_User]
	
	GRANT EXECUTE ON [dbo].[ProcessCandidateSequences] TO [DMS_SP_User]
	
	GRANT EXECUTE ON [dbo].[PostLogEntry] TO [DMS_SP_User]
	
	GRANT EXECUTE ON [dbo].[VerifyUpdateEnabled] TO [DMS_SP_User]
	
	GRANT EXECUTE ON [dbo].[CalculateMonoisotopicMass] TO [DMS_SP_User]
	
	GRANT EXECUTE ON [dbo].[GetParamFileModInfo] TO [DMS_SP_User]
	GRANT EXECUTE ON [dbo].[GetIDFromNormalizedSequence] TO [DMS_SP_User]
	GRANT EXECUTE ON [dbo].[GetIDFromRawSequence] TO [DMS_SP_User]
	GRANT EXECUTE ON [dbo].[GetIDsForRawSequences] TO [DMS_SP_User]

	Return 0

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

