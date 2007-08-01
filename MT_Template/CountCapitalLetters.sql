/****** Object:  StoredProcedure [dbo].[CountCapitalLetters] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.CountCapitalLetters
/****************************************************
**
**	Desc:
**		Counts the number of capital letters in @InputString
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 06/09/2004
**			  06/12/2004 by mem - Optimized while loop execution speed
**    
*****************************************************/
(
	@InputString varchar(8000) = '',
	@CapitalLetterCount int=0 OUTPUT
)
AS

	Set NoCount On

	Declare @CharIndex int,
			@StringLength int,
 			@CharCode int
	
	-- Count the number of Upper Case characters in @InputString using a While loop
	Set @StringLength = Len(IsNull(@InputString, ''))
	Set @CharIndex = 1
	Set @CapitalLetterCount = 0
	
	While @CharIndex <= @StringLength
	Begin
		-- Lookup the Ascii code for the next character in @InputString
		Set @CharCode = ASCII(Substring(@InputString, @CharIndex, 1))
		If @CharCode >=65 AND @CharCode <= 90
			Set @CapitalLetterCount = @CapitalLetterCount + 1
		
		-- Increment @CharIndex
		Set @CharIndex = @CharIndex + 1
	End

	Return 0


GO
GRANT EXECUTE ON [dbo].[CountCapitalLetters] TO [DMS_SP_User]
GO
