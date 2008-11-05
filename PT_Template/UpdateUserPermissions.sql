/****** Object:  StoredProcedure [dbo].[UpdateUserPermissions] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
**			07/15/2006 mem - Updated to use Sql Server 2005 syntax if possible
**			08/10/2006 mem - Added MTS_DB_Reader
**			08/14/2006 mem - Updated to use dynamic sql to run the schema drops on Sql Server 2005; necessary to keep this SP compatible wiht Sql Server 2000
**			11/14/2007 mem - Updated to grant ShowPlan permissions
**			04/21/2008 mem - Added ShowPlan permissions for MTUser
**			11/04/2008 mem - Now calling UpdateUserPermissionsViewDefinitions for MTS_DB_Dev and MTS_DB_Lite
**    
*****************************************************/
AS
	Set NoCount On
	
	---------------------------------------------------
	-- Determine whether or not we're running Sql Server 2005 or newer
	---------------------------------------------------
	Declare @VersionMajor int
	Declare @UseSystemViews tinyint
	Declare @S nvarchar(512)
	
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
		Declare @Sql varchar(4000)

		Set @Sql = 'if exists (select * from sys.schemas where name = ''MTUser'') drop schema MTUser'
		Exec (@Sql)

		Set @Sql = 'if exists (select * from sys.sysusers where name = ''MTUser'') drop user MTUser'
		Exec (@Sql)

		Set @Sql = 'create user MTUser for login MTUser'
		Exec (@Sql)
		
		exec sp_addrolemember 'db_datareader', 'MTUser'
		exec sp_addrolemember 'DMS_SP_User', 'MTUser'


		Set @Sql = 'if exists (select * from sys.schemas where name = ''MTAdmin'') drop schema MTAdmin'
		Exec (@Sql)

		Set @Sql = 'if exists (select * from sys.sysusers where name = ''MTAdmin'') drop user MTAdmin'
		Exec (@Sql)

		Set @Sql = 'create user MTAdmin for login MTAdmin'
		Exec (@Sql)
		
		exec sp_addrolemember 'db_datareader', 'MTAdmin'
		exec sp_addrolemember 'db_datawriter', 'MTAdmin'
		exec sp_addrolemember 'DMS_SP_User', 'MTAdmin'


		Set @Sql = 'if exists (select * from sys.schemas where name = ''MTS_DB_Dev'') drop schema MTS_DB_Dev'
		Exec (@Sql)

		Set @Sql = 'if exists (select * from sys.sysusers where name = ''MTS_DB_Dev'') drop user MTS_DB_Dev'
		Exec (@Sql)

		set @S = 'create user MTS_DB_Dev for login [' + @@ServerName + '\MTS_DB_Dev]'
		exec sp_executesql @S
		
		exec sp_addrolemember 'db_owner', 'MTS_DB_DEV'
		exec sp_addrolemember 'db_ddladmin', 'MTS_DB_DEV'
		exec sp_addrolemember 'db_backupoperator', 'MTS_DB_DEV'
		exec sp_addrolemember 'db_datareader', 'MTS_DB_DEV'
		exec sp_addrolemember 'db_datawriter', 'MTS_DB_DEV'
		exec sp_addrolemember 'DMS_SP_User', 'MTS_DB_DEV'


		Set @Sql = 'if exists (select * from sys.schemas where name = ''MTS_DB_Lite'') drop schema MTS_DB_Lite'
		Exec (@Sql)

		Set @Sql = 'if exists (select * from sys.sysusers where name = ''MTS_DB_Lite'') drop user MTS_DB_Lite'
		Exec (@Sql)

		set @S = 'create user MTS_DB_Lite for login [' + @@ServerName + '\MTS_DB_Lite]'
		exec sp_executesql @S
		exec sp_addrolemember 'db_datareader', 'MTS_DB_Lite'
		exec sp_addrolemember 'db_datawriter', 'MTS_DB_Lite'
		exec sp_addrolemember 'DMS_SP_User', 'MTS_DB_Lite'


		Set @Sql = 'if exists (select * from sys.schemas where name = ''MTS_DB_Reader'') drop schema MTS_DB_Reader'
		Exec (@Sql)

		Set @Sql = 'if exists (select * from sys.sysusers where name = ''MTS_DB_Reader'') drop user MTS_DB_Reader'
		Exec (@Sql)

		set @S = 'create user MTS_DB_Reader for login [' + @@ServerName + '\MTS_DB_Reader]'
		exec sp_executesql @S
		
		exec sp_addrolemember 'db_datareader', 'MTS_DB_Reader'
		exec sp_addrolemember 'DMS_SP_User', 'MTS_DB_Reader'
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

	grant update on T_Seq_Candidates(Seq_ID) to DMS_SP_User

	grant showplan to MTS_DB_Reader
	grant showplan to MTUser

	-- Call UpdateUserPermissionsViewDefinitions to grant view definition for each Stored Procedure and grant showplan
	exec UpdateUserPermissionsViewDefinitions @UserList='MTS_DB_Dev, MTS_DB_Lite'

	Return 0


GO
GRANT VIEW DEFINITION ON [dbo].[UpdateUserPermissions] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateUserPermissions] TO [MTS_DB_Lite]
GO
