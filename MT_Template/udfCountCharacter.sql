/****** Object:  UserDefinedFunction [dbo].[udfCountCharacter] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION dbo.udfCountCharacter
/****************************************************	
**	Counts the number of occurrences of a 
**  specific character (or substring) in a string
**
**	Auth:	mem
**	Date:	03/08/2011
**  
****************************************************/
(
	@TextToSearch varchar(2048),
	@CharacterToFind varchar(128)
)
RETURNS int
AS
BEGIN
	
	Declare @CharIndex int = 0
	Declare @Count int = 0
	Declare @Continue tinyint = 1
	
	While @Continue = 1
	Begin
		Set @CharIndex = CharIndex(@CharacterToFind, @TextToSearch, @CharIndex+1)
		If @CharIndex > 0
			Set @Count = @Count + 1
		Else
			Set @Continue = 0
	End
   		
	RETURN  @Count
END


GO
