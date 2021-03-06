/****** Object:  StoredProcedure [dbo].[UpdateUserPermissions] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE UpdateUserPermissions
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
**			07/15/2006 mem - Updated to use Sql Server 2005 syntax if possible
**			08/10/2006 mem - Added MTS_DB_Reader
**			04/21/2008 mem - Updated to grant ShowPlan permissions
**			11/04/2008 mem - Now calling UpdateUserPermissionsViewDefinitions for MTS_DB_Dev and MTS_DB_Lite
**			10/24/2012 mem - Added DMSReader
**			03/02/2015 mem - Now only updating DMSReader if the user exists in sys.sysusers
**    
*****************************************************/
AS
	Set NoCount On
	
	---------------------------------------------------
	-- Determine whether or not we're running Sql Server 2005 or newer
	---------------------------------------------------
	Declare @VersionMajor int
	Declare @UseSystemViews tinyint
	Declare @S nvarchar(256)
	
	exec MT_Main.dbo.GetServerVersionInfo @VersionMajor output

	If @VersionMajor >= 9
		set @UseSystemViews = 1
	else
		set @UseSystemViews = 0

	If @UseSystemViews = 0
	Begin
		exec sp_revokedbaccess 'MTUser'
		exec sp_grantdbaccess 'MTUser'

		exec sp_revokedbaccess 'MTAdmin'
		exec sp_grantdbaccess 'MTAdmin'

		exec sp_revokedbaccess 'MTS_DB_Dev'
		set @S = @@ServerName + '\MTS_DB_DEV'
		exec sp_grantdbaccess @S, 'MTS_DB_DEV'

		exec sp_revokedbaccess 'MTS_DB_Lite'
		set @S = @@ServerName + '\MTS_DB_Lite'
		exec sp_grantdbaccess @S, 'MTS_DB_Lite'

		exec sp_revokedbaccess 'MTS_DB_Reader'
		set @S = @@ServerName + '\MTS_DB_Reader'
		exec sp_grantdbaccess @S, 'MTS_DB_Reader'
	End
	Else
	Begin
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
			
		set @S = 'create user MTS_DB_Dev for login [' + @@ServerName + '\MTS_DB_Dev]'
		exec sp_executesql @S
		
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


		set @S = 'create user MTS_DB_Lite for login [' + @@ServerName + '\MTS_DB_Lite]'
		exec sp_executesql @S
		exec sp_addrolemember 'db_datareader', 'MTS_DB_Lite'
		exec sp_addrolemember 'db_datawriter', 'MTS_DB_Lite'
		exec sp_addrolemember 'DMS_SP_User', 'MTS_DB_Lite'


		if exists (select * from sys.schemas where name = 'MTS_DB_Reader')
			drop schema MTS_DB_Reader
		if exists (select * from sys.sysusers where name = 'MTS_DB_Reader')
			drop user MTS_DB_Reader
			
		set @S = 'create user MTS_DB_Reader for login [' + @@ServerName + '\MTS_DB_Reader]'
		exec sp_executesql @S
		
		exec sp_addrolemember 'db_datareader', 'MTS_DB_Reader'
		exec sp_addrolemember 'DMS_SP_User', 'MTS_DB_Reader'
		
		if exists (select * from sys.sysusers where name = 'DMSReader')
		Begin
			if exists (select * from sys.schemas where name = 'DMSReader')
				drop schema DMSReader
			if exists (select * from sys.sysusers where name = 'DMSReader')
				drop user DMSReader

			create user DMSReader for login DMSReader
			exec sp_addrolemember 'db_datareader', 'DMSReader'
		End
		
			
	End

	exec sp_addrolemember 'db_datareader', 'MTUser'
	exec sp_addrolemember 'DMS_SP_User', 'MTUser'

	exec sp_addrolemember 'db_datareader', 'MTAdmin'
	exec sp_addrolemember 'db_datawriter', 'MTAdmin'
	exec sp_addrolemember 'DMS_SP_User', 'MTAdmin'

	exec sp_addrolemember 'db_owner', 'MTS_DB_DEV'
	exec sp_addrolemember 'db_ddladmin', 'MTS_DB_DEV'
	exec sp_addrolemember 'db_backupoperator', 'MTS_DB_DEV'
	exec sp_addrolemember 'db_datareader', 'MTS_DB_DEV'
	exec sp_addrolemember 'db_datawriter', 'MTS_DB_DEV'
	exec sp_addrolemember 'DMS_SP_User', 'MTS_DB_DEV'

	exec sp_addrolemember 'db_datareader', 'MTS_DB_Lite'
	exec sp_addrolemember 'db_datawriter', 'MTS_DB_Lite'
	exec sp_addrolemember 'DMS_SP_User', 'MTS_DB_Lite'

	exec sp_addrolemember 'db_datareader', 'MTS_DB_Reader'
	exec sp_addrolemember 'DMS_SP_User', 'MTS_DB_Reader'

	grant showplan to MTS_DB_Reader
	grant showplan to MTUser

	-- Call UpdateUserPermissionsViewDefinitions to grant view definition for each Stored Procedure and grant showplan
	exec UpdateUserPermissionsViewDefinitions @UserList='MTS_DB_Dev, MTS_DB_Lite'

	Return 0


GO
GRANT VIEW DEFINITION ON [dbo].[UpdateUserPermissions] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateUserPermissions] TO [MTS_DB_Lite] AS [dbo]
GO
