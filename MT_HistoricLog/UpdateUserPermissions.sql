/****** Object:  StoredProcedure [dbo].[UpdateUserPermissions] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateUserPermissions]
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
	create user MTS_DB_Dev for login [Proteinseqs\MTS_DB_Dev]
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
	create user MTS_DB_Lite for login [Proteinseqs\MTS_DB_Lite]
	exec sp_addrolemember 'db_datareader', 'MTS_DB_Lite'
	exec sp_addrolemember 'db_datawriter', 'MTS_DB_Lite'
	exec sp_addrolemember 'DMS_SP_User', 'MTS_DB_Lite'

	Return 0


GO
