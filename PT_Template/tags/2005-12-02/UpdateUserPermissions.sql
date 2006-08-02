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
**		Auth: mem
**		Date: 12/13/2004
**			  01/27/2005 mem - Added MTS_DB_Dev and MTS_DB_Lite
**    
*****************************************************/
AS
	Set NoCount On
	
	exec sp_revokedbaccess 'MTUser'
	exec sp_grantdbaccess 'MTUser'
	exec sp_addrolemember 'db_datareader', 'MTUser'
	exec sp_addrolemember 'DMS_SP_User', 'MTUser'

	exec sp_revokedbaccess 'MTAdmin'
	exec sp_grantdbaccess 'MTAdmin'
	exec sp_addrolemember 'db_datareader', 'MTAdmin'
	exec sp_addrolemember 'db_datawriter', 'MTAdmin'
	exec sp_addrolemember 'DMS_SP_User', 'MTAdmin'

	exec sp_revokedbaccess 'MTS_DB_Dev'
	exec sp_grantdbaccess 'albert\MTS_DB_DEV', 'MTS_DB_DEV'

	exec sp_addrolemember 'db_owner', 'MTS_DB_DEV'
	exec sp_addrolemember 'db_ddladmin', 'MTS_DB_DEV'
	exec sp_addrolemember 'db_backupoperator', 'MTS_DB_DEV'
	exec sp_addrolemember 'db_datareader', 'MTS_DB_DEV'
	exec sp_addrolemember 'db_datawriter', 'MTS_DB_DEV'
	exec sp_addrolemember 'DMS_SP_User', 'MTS_DB_DEV'

	exec sp_revokedbaccess 'MTS_DB_Lite'
	exec sp_grantdbaccess 'albert\MTS_DB_Lite', 'MTS_DB_Lite'

	exec sp_addrolemember 'db_datareader', 'MTS_DB_Lite'
	exec sp_addrolemember 'db_datawriter', 'MTS_DB_Lite'
	exec sp_addrolemember 'DMS_SP_User', 'MTS_DB_Lite'

	Return 0



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

