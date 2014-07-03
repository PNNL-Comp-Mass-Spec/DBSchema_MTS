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
**
*****************************************************/
(
	@newDBName varchar(64),
	@message varchar(255) = '' OUTPUT
)
AS
	Set NoCount On
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0


	---------------------------------------------------
	-- Check for invalid characters in @newDBName
	---------------------------------------------------
	
	If Len(@newDBName) = 0
	Begin
		Set @message = 'Database name is blank'
		Set @myError = 120
		goto done
	End

	If @newDBName Like '% %'
	Begin
		Set @message = 'Database name contains a space'
		Set @myError = 121
		goto done
	End
		
	If CharIndex(Char(10), @newDBName) > 0 Or CharIndex(Char(13), @newDBName) > 0
	Begin
		Set @message = 'Database name contains a carriage return'
		Set @myError = 123
		goto done
	End
	
	-----------------------------------------------
	-- Exit
	-----------------------------------------------
Done:	
	return @myError


GO
