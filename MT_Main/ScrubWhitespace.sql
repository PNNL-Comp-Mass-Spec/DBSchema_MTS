/****** Object:  UserDefinedFunction [dbo].[ScrubWhitespace] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION dbo.ScrubWhitespace
/****************************************************
**
**	Desc: Removes whitespace (including Cr, Lf, and tab) from the start and end of text
**
**	Return value: error message
**
**	Parameters: 
**
**	Auth:	mem
**	Date:	07/01/2014 mem - Initial release
**    
*****************************************************/
(
	@text varchar(Max)
)
RETURNS varchar(max)
AS
BEGIN

	Declare @newText varchar(max)
		
	Set @newText = LTrim(RTrim(IsNull(@text, '')))
				
	Declare @ContinueChecking tinyint
	Declare @matchChar varchar(1)

	Set @ContinueChecking = 1
	While @ContinueChecking = 1 and Len(@newText) > 0
	Begin
		-- Check for Cr, Lf, or Tab on the left edge of the text
		Set @matchChar = Substring(@newText, 1, 1)

		If    @matchChar = Char(10) -- CR
		   OR @matchChar = Char(13) -- LF
		   OR @matchChar = Char(9)  -- Tab
		Begin
			Set @newText = LTrim(Substring(@newText, 2, Len(@newText)-1))
		End
		Else
		Begin
			Set @ContinueChecking = 0
		End
	End

	Set @ContinueChecking = 1
	While @ContinueChecking = 1 and Len(@newText) > 0
	Begin
		-- Check for Cr, Lf, or Tab on the right edge of the text
		Set @matchChar = Substring(@newText, Len(@newText), 1)

		If    @matchChar = Char(10) -- CR
		   OR @matchChar = Char(13) -- LF
		   OR @matchChar = Char(9)  -- Tab
		Begin
			Set @newText = RTrim(Substring(@newText, 1, Len(@newText)-1))
		End
		Else
		Begin
			Set @ContinueChecking = 0
		End
	End

	Return @newText
		
END

GO
