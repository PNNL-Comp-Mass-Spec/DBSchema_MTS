/****** Object:  StoredProcedure [dbo].[QuoteNameList] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.QuoteNameList
/****************************************************
**
**	Desc: 
**	Adds single quotes around each entry in @entryList,
**  returning the result in @entryListQuoted
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 4/7/2004
**    
*****************************************************/
	@entryList varchar(7000) = '',								-- Comma-separated list of values
	@entryListQuoted varchar(8000) = '' output,
	@message varchar(512) = '' output,
	@listSeparator char(1) = ',',								-- Default is a comma
	@quoteCharacter char(1) = ''''								-- Default is a single quote
As
	set nocount on

	declare @myError int
	set @myError = 0

	set @message = ''
	declare @result int
	
	---------------------------------------------------
	-- Assure that each entry in @entryList is surrounded by @quoteCharacter
	---------------------------------------------------

	Declare @singleEntry varchar(255)
	Declare @sepLoc int

	Set @entryList = LTrim(RTrim(@entryList))
	
	Set @entryListQuoted = ''
	
	While Len(@entryList) > 0
	Begin
		Set @sepLoc = CharIndex(@listSeparator, @entryList)
		If @sepLoc = 0		
		 Begin
			-- No list separator found
			Set @singleEntry = @entryList
			Set @entryList = ''
		 End
		Else
		 Begin
			-- List separator found
			Set @singleEntry = SubString(@entryList, 1, @sepLoc-1)
			Set @entryList = LTrim(SubString(@entryList, @sepLoc+1, Len(@entryList) - @sepLoc))
		 End

		Set @singleEntry = LTrim(RTrim(@singleEntry))
		If SubString(@singleEntry,1,1) <> @quoteCharacter
			Set @singleEntry = @quoteCharacter + @singleEntry

		If SubString(@singleEntry,Len(@singleEntry),1) <> @quoteCharacter
			Set @singleEntry = @singleEntry + @quoteCharacter
		
		If Len(@entryListQuoted) > 0
			Set @entryListQuoted = @entryListQuoted + ', '
		
		Set @entryListQuoted = @entryListQuoted + @singleEntry
	End

Done:
	return @myError


GO
GRANT EXECUTE ON [dbo].[QuoteNameList] TO [DMS_SP_User]
GO
GRANT EXECUTE ON [dbo].[QuoteNameList] TO [MTUser]
GO
