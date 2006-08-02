SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SetPermissionRestrictions]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[SetPermissionRestrictions]
GO


CREATE PROCEDURE dbo.SetPermissionRestrictions
/****************************************************
**
**	Desc: 
**		For the logins in @UsersToRestrict, restricts 
**		read/write access to all tables and views except
**		those listed in @PublicObjects
**		
**		Optionally, edit @PermissionsList to customize the restrictions applied
**
**	Return values: 0:  success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 05/23/2005
**    
*****************************************************/
(
	@UsersToRestrict varchar(1024) = 'dmswebuser, MTUser, MTAdmin, DMS_SP_User',
	@PublicObjects varchar(1024) = 'T_General_Statistics, T_Log_Entries, T_Process_Config, T_Process_Config_Parameters, V_Config_Info, V_DB_Schema_Version, V_General_Statistics_Report, V_Log_Report, V_Process_Config, V_Table_Row_Counts' ,
	@message varchar(512) = '' output
)
As
	set nocount on
	
	declare @myError int
	declare @myRowcount int
	set @myRowcount = 0
	set @myError = 0

	declare @CommaLoc int
	declare @ObjectName varchar(256)

	set @message = ''

	--------------------------------------------------------------
	-- Create two temporary tables
	--------------------------------------------------------------
	--
	if exists (select * from dbo.sysobjects where id = object_id(N'#Tmp_ObjectList') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table #Tmp_ObjectList
	CREATE TABLE #Tmp_ObjectList (
		[ObjectName] varchar(256) NOT NULL,
		[ID] int
	)

	if exists (select * from dbo.sysobjects where id = object_id(N'#Tmp_PublicObjects') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table #Tmp_PublicObjects
	CREATE TABLE #Tmp_PublicObjects (
		[ObjectName] varchar(128) NOT NULL,
		[UniqueID] int NOT NULL identity
	)

	--------------------------------------------------------------
	-- Split @PublicObjects on commas to populate #Tmp_PublicObjects
	--------------------------------------------------------------
	--
	Set @CommaLoc = CharIndex(',', @PublicObjects)
	While @CommaLoc > 1
	Begin

		Set @ObjectName = LTrim(RTrim(Left(@PublicObjects, @CommaLoc-1)))
		Set @PublicObjects = LTrim(RTrim(SubString(@PublicObjects, @CommaLoc+1, Len(@PublicObjects))))

		INSERT INTO #Tmp_PublicObjects ([ObjectName]) VALUES (@ObjectName)
	
		Set @CommaLoc = CharIndex(',', @PublicObjects)
	End
	
	If Len(@PublicObjects) > 0
		INSERT INTO #Tmp_PublicObjects ([ObjectName]) VALUES (@PublicObjects)


	--------------------------------------------------------------
	-- First revoke (reset) any previously defined permissions
	-- for the given users for all objects
	--------------------------------------------------------------
	--	
	INSERT INTO #Tmp_ObjectList (ObjectName, ID)
	SELECT [Name], ID
	FROM sysobjects
	WHERE xtype IN ('U', 'V') AND status > 0
	ORDER BY ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount = 0
	Begin
		Set @message = 'No user tables or views are present in sysobjects; nothing to update'
		Goto Done
	End
	
	Exec SetPermissions 'REVOKE', 'ALL', 'public'
	Exec SetPermissions 'REVOKE', 'ALL', @UsersToRestrict
	
	--------------------------------------------------------------
	-- Now deny the given permissions in the matching objects for the given users
	-- Sql Server Books On Line suggests granting SELECT to public before denying any specific users
	--------------------------------------------------------------
	--
	TRUNCATE TABLE #Tmp_ObjectList

	INSERT INTO #Tmp_ObjectList (ObjectName, ID)
	SELECT [Name], ID
	FROM sysobjects
	WHERE xtype IN ('U', 'V') AND status > 0 AND [Name] NOT IN (SELECT ObjectName FROM #Tmp_PublicObjects)
	ORDER BY ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount = 0
	Begin
		Set @message = 'No matching tables or views were found in sysobjects; nothing to update'
		Goto Done
	End
	Else
		Set @Message = 'Updating permissions for ' + convert(varchar(9), @myRowCount) + ' tables & views'

	Exec SetPermissions 'GRANT', 'SELECT', 'public'
	Exec SetPermissions 'DENY', 'SELECT, INSERT, UPDATE, DELETE', @UsersToRestrict
	

Done:
	SELECT ObjectName AS [Objects Updated]
	FROM #Tmp_ObjectList
	ORDER BY ObjectName

	RETURN 


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

