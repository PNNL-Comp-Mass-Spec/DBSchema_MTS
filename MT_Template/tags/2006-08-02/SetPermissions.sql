SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SetPermissions]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[SetPermissions]
GO


CREATE PROCEDURE dbo.SetPermissions
/****************************************************
**
**	Desc: 
**		Loops through the objects in temporary table #Tmp_ObjectList,
**		applying the command @PermissionCommand to users @UserList
**
**		The temporary table needs to be created and populated by the calling procedure
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
	@PermissionCommand varchar(64),				-- single command, typically 'GRANT', 'REVOKE', or 'DENY'
	@PermissionsList varchar(128),				-- comma separated list, typically 'SELECT, INSERT, UPDATE, DELETE'
	@UserList varchar(1024),
	@Cascade tinyint = 1,						-- If 1, then appends 'Cascade' to the command
	@message varchar(512) = '' output
)
As
	set nocount on
	
	declare @myError int
	declare @myRowcount int
	set @myRowcount = 0
	set @myError = 0

	declare @Continue int
	declare @ObjectID int
	declare @ObjectName varchar(256)

	declare @S varchar(4096)
	
	--------------------------------------------------------------
	-- Validate that @Cascade is 0 when @UserList = 'public'
	--------------------------------------------------------------
	--
	If @UserList = 'public'
		Set @Cascade = 0
		
	--------------------------------------------------------------
	-- Loop through the entries in #Tmp_ObjectList
	--------------------------------------------------------------
	--
	Set @ObjectID = 0
	Set @Continue = 1
	While @Continue = 1
	Begin
		SELECT TOP 1 @ObjectName = ObjectName, @ObjectID = ID
		FROM #Tmp_ObjectList
		WHERE ID > @ObjectID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		if @myRowCount <> 1
			Set @Continue = 0
		Else
		Begin
			
			Set @S = @PermissionCommand + ' ' + @PermissionsList + ' ON ' +  @ObjectName + ' TO ' + @UserList
			if @Cascade = 1
				Set @S = @S + ' CASCADE'
				
			Exec (@S)
		End
	End

Done:
	RETURN @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

