/****** Object:  StoredProcedure [dbo].[CheckAccessPermission] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE CheckAccessPermission
/****************************************************
** 
**		Desc: 
**		Verify that currently logged-in user
**		has permision to execute the named stored procedure
**
**		Return values: 0: success, otherwise, error code
** 
** 
**		Auth: grk
**		Date: 9/10/2002
**    
*****************************************************/
	@ObjectName varchar(128) = 'CreateAccessGroup'
AS
	SET NOCOUNT ON
	
	declare @ok int
	set @ok = 1

	declare @objID int
	set @objID = 0
	
	declare @p int
	set @p= 0

	set @objID = OBJECT_ID(@ObjectName)
	--
	if @objID is not null
	begin
		set @p = permissions( @objID )
		if @p & 32 > 0 set @ok = 0
	end

	RETURN @ok

GO
GRANT EXECUTE ON [dbo].[CheckAccessPermission] TO [DMS_SP_User]
GO
