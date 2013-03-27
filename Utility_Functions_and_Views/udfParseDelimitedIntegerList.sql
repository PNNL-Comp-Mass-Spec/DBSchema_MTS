SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

ALTER FUNCTION dbo.udfParseDelimitedIntegerList
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
**			03/27/2013 mem - Now replacing carriage return and line feed characters with @Delimiter
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
		
		-- Replace any CR or LF characters with @Delimiter
		If @DelimitedList Like '%' + Char(13) + '%'
			Set @DelimitedList = LTrim(RTrim(Replace(@DelimitedList, Char(13),  @Delimiter)))

		If @DelimitedList Like '%' + Char(10) + '%'
			Set @DelimitedList = LTrim(RTrim(Replace(@DelimitedList, Char(10),  @Delimiter)))

		If @Delimiter <> Char(9)
		Begin
			-- Replace any tab characters with @Delimiter
			If @DelimitedList Like '%' + Char(9)  + '%'
				Set @DelimitedList = LTrim(RTrim(Replace(@DelimitedList, Char(9),  @Delimiter)))
		End
		
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO
