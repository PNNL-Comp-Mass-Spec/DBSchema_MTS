/****** Object:  UserDefinedFunction [dbo].[udfParseDelimitedIntegerList] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION dbo.udfParseDelimitedIntegerList
/****************************************************	
**	Parses the text in @DelimitedList and returns a table
**	containing the values
**
**	@DelimitedList should be of the form 'Value1,Value2'
**	Will not return empty string values, e.g. if the list is 'Value1,,Value2' or ',Value1,Value2'
**	 then the table will only contain entries 'Value1' and 'Value2'
**
**
**	Auth:	mem
**	Date:	11/30/2006
**			03/14/2007 mem - Changed @DelimitedList parameter from varchar(8000) to varchar(max)
**			04/02/2012 mem - Now removing Tab characters
**  
****************************************************/
(
	@DelimitedList varchar(max),
	@Delimiter varchar(2) = ','
)
RETURNS @tmpValues TABLE(Value int)
AS
BEGIN
	
	Declare @continue tinyint
	Declare @StartPosition int
	Declare @DelimiterPos int
	
	Declare @Value varchar(2048)
	
	Set @DelimitedList = IsNull(@DelimitedList, '')
	
	If Len(@DelimitedList) > 0
	Begin -- <a>
		Set @StartPosition = 1
		Set @continue = 1
		While @continue = 1
		Begin -- <b>
			Set @DelimiterPos = CharIndex(@Delimiter, @DelimitedList, @StartPosition)
			If @DelimiterPos = 0
			Begin
				Set @DelimiterPos = Len(@DelimitedList) + 1
				Set @continue = 0
			End

			If @DelimiterPos > @StartPosition
			Begin -- <c>
				Set @Value = LTrim(RTrim(SubString(@DelimitedList, @StartPosition, @DelimiterPos - @StartPosition)))
				
				If @Delimiter <> Char(9)
				Begin
					 -- Remove any tab characters present in @Value
					 Set @Value = Replace(@Value, Char(9), '')
				End
				
				If Len(@Value) > 0 And IsNumeric(@Value) = 1
				Begin
					INSERT INTO @tmpValues (Value)
					VALUES (Convert(int, @Value))
				End
			End -- </c>

			Set @StartPosition = @DelimiterPos + 1
		End -- </b>
	End -- </a>
	
	RETURN
END


GO
