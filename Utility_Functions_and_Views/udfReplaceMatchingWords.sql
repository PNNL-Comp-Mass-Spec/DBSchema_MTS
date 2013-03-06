SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

CREATE FUNCTION dbo.udfReplaceMatchingWords
/****************************************************	
**	Looks for the given text in a string and replaces it with new text
**  However, only matches full words, where word boundaries are defined by 
**  any character besides A-Z, a-z, 0-9, and _
**
**	Auth:	mem
**	Date:	11/28/2007
**  
****************************************************/
(
	@SearchText varchar(max),
	@MatchWord varchar(512),
	@ReplacementWord varchar(512)
)
RETURNS varchar(max)
AS
BEGIN
	Declare @CharLoc int
	Declare @StartLoc int
	Declare @Continue tinyint

	Declare @CharCheck char
	
	Declare @LeftValid tinyint
	Declare @RightValid tinyint

	Declare @NewText varchar(max)
	Set @NewText = ''
		
	Set @StartLoc = 1
	Set @Continue = 1
	
	While @Continue = 1
	Begin
		-- Look for @MatchWord in @SearchText
		Set @CharLoc = CharIndex(@MatchWord, @SearchText, @StartLoc)
		If @CharLoc > 0
		Begin
			Set @LeftValid = 1
			Set @RightValid = 1
			
			-- See if the character to the left of @CharLoc defines a word boundary
			If @CharLoc > 1
			Begin
				Set @CharCheck = Substring(@SearchText, @CharLoc-1, 1)
				If @CharCheck Like '[A-Z]' OR 
				   @CharCheck Like '[a-z]' OR 
				   @CharCheck Like '[0-9]' OR 
				   @CharCheck = '_'
					Set @LeftValid = 0			   
			End
			
			
			If @CharLoc < Len(@SearchText)
			Begin
				Set @CharCheck = Substring(@SearchText, @CharLoc + Len(@MatchWord), 1)
				If @CharCheck Like '[A-Z]' OR 
				   @CharCheck Like '[a-z]' OR 
				   @CharCheck Like '[0-9]' OR 
				   @CharCheck = '_'
					Set @RightValid = 0			   
			End
			
			
			If @LeftValid = 1 And @RightValid = 1
				Set @NewText = @NewText + Substring(@SearchText, @StartLoc, @CharLoc - @StartLoc) + @ReplacementWord
			Else
				Set @NewText = @NewText + Substring(@SearchText, @StartLoc, @CharLoc - @StartLoc + Len(@MatchWord))
			
			
			Set @StartLoc = @CharLoc + Len(@MatchWord)			
		End
		Else
		Begin
			Set @NewText = @NewText + Substring(@SearchText, @StartLoc, Len(@SearchText))
			Set @Continue = 0
		End
	End
		
	RETURN  @NewText
END

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[udfReplaceMatchingWords]  TO [DMS_SP_User]
GO
