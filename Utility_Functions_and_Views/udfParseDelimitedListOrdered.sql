GO

CREATE FUNCTION dbo.udfParseDelimitedListOrdered
/****************************************************	
**	Parses the text in @DelimitedList and returns a table
**	 containing the values.  The table includes column EntryID
**   to allow the calling procedure to sort the data based on the 
**   data order in @DelimitedList.  The first row will have EntryID = 1
**
**  Note that if two commas in a row are encountered, then the resultant table
**   will contain an empty cell for that row
**
**	@DelimitedList should be of the form 'Value1,Value2'
**
**	Auth:	mem
**	Date:	10/16/2007
**			03/27/2013 mem - Now replacing Tab characters, carriage returns and line feeds with @Delimiter
**  
****************************************************/
(
	@DelimitedList varchar(max),
	@Delimiter varchar(2) = ','
)
RETURNS @tmpValues TABLE(EntryID int NOT NULL, Value varchar(2048) NULL)
AS
BEGIN
	
	Declare @continue tinyint
	Declare @StartPosition int
	Declare @DelimiterPos int
	
	Declare @Value varchar(2048)
	Declare @EntryID int
	Set @EntryID = 1
	
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

			If @DelimiterPos >= @StartPosition
			Begin -- <c>
				If @DelimiterPos > @StartPosition
					Set @Value = LTrim(RTrim(SubString(@DelimitedList, @StartPosition, @DelimiterPos - @StartPosition)))
				Else
					Set @Value = ''
				
				INSERT INTO @tmpValues (EntryID, Value)
				VALUES (@EntryID, @Value)
				
				Set @EntryID = @EntryID + 1
			end -- </c>

			Set @StartPosition = @DelimiterPos + 1
		End -- </b>
	End -- </a>
	
	RETURN
END

GO