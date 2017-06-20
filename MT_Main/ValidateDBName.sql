/****** Object:  StoredProcedure [dbo].[ValidateDBName] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ValidateDBName
/****************************************************
**
**	Desc: 
**		Validates that a new PT or MT database name does not contain any invalid characters
**
**	Parameters:
**
**	Auth:	mem
**	Date:	04/14/2014 mem - Initial verion
**			06/20/2017 mem - Raise an error if @newDBNameRoot is 64 characters long
**							 It's likely the name was over 64 characters long and got truncated prior to the call to this procedure
**
*****************************************************/
(
	@newDBNameRoot varchar(64),
	@message varchar(255) = '' OUTPUT
)
AS
	Set NoCount On
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0


	---------------------------------------------------
	-- Check for invalid characters in @newDBNameRoot
	---------------------------------------------------
	
	If Len(@newDBNameRoot) = 0
	Begin
		Set @message = 'Database name is blank'
		Set @myError = 120
		goto done
	End

	If @newDBNameRoot Like '% %'
	Begin
		Set @message = 'Database name contains a space'
		Set @myError = 121
		goto done
	End
		
	If CharIndex(Char(10), @newDBNameRoot) > 0 Or CharIndex(Char(13), @newDBNameRoot) > 0
	Begin
		Set @message = 'Database name contains a carriage return'
		Set @myError = 123
		goto done
	End
	
	If Len(@newDBNameRoot) > 63
	Begin
		Set @message = 'Base database name must be less than 64 characters (and ideally should be 40 characters or less)'
		Set @myError = 125
		goto done
	End
	
	-----------------------------------------------
	-- Exit
	-----------------------------------------------
Done:	
	return @myError


GO
