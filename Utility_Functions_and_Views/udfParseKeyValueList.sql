if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[udfParseKeyValueList]') and xtype in (N'FN', N'IF', N'TF'))
drop function [dbo].[udfParseKeyValueList]
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS OFF 
GO

CREATE FUNCTION dbo.udfParseKeyValueList
/****************************************************	
**	Parses the text in @KeyValueList and returns a table
**	containing the keywords and values
**
**	@KeyValueList should be of the form 'KeyWord1=Value1,KeyWord2=Value2'
**
**	Auth:	mem
**	Date:	06/06/2006
**			03/14/2007 mem - Changed @KeyValueList parameter from varchar(4000) to varchar(max)
**  
****************************************************/
(
	@KeyValueList varchar(max),
	@ListDelimiter varchar(2) = ',',
	@KeyValueDelimiter varchar(2) = '='
)
RETURNS @tmpKeyValuePairs TABLE(Keyword varchar(2048), Value varchar(2048))
AS
BEGIN
	Declare @continue tinyint
	Declare @StartPosition int
	Declare @Delimiter1Pos int
	Declare @Delimiter2Pos int
	
	Declare @KeyValuePair varchar(4096)
	Declare @Keyword varchar(2048)
	Declare @Value varchar(2048)
	
	Set @KeyValueList = IsNull(@KeyValueList, '')
	
	If Len(@KeyValueList) > 0
	Begin -- <a>
		Set @StartPosition = 1
		Set @continue = 1
		While @continue = 1
		Begin -- <b>
			Set @Delimiter1Pos = CharIndex(@ListDelimiter, @KeyValueList, @StartPosition)
			If @Delimiter1Pos = 0
			Begin
				Set @Delimiter1Pos = Len(@KeyValueList) + 1
				Set @continue = 0
			End

			If @Delimiter1Pos > @StartPosition
			Begin -- <c>
				Set @KeyValuePair = LTrim(RTrim(SubString(@KeyValueList, @StartPosition, @Delimiter1Pos - @StartPosition)))
				Set @Delimiter2Pos = CharIndex(@KeyValueDelimiter, @KeyValuePair)
				
				If @Delimiter2Pos > 0
				Begin
					Set @Keyword = LTrim(RTrim(Left(@KeyValuePair, @Delimiter2Pos - 1)))
					Set @Value = LTrim(RTrim(SubString(@KeyValuePair, @Delimiter2Pos + 1, Len(@KeyValuePair))))
					
					INSERT INTO @tmpKeyValuePairs (Keyword, Value)
					VALUES (@Keyword, @Value)
				End
				Else
				Begin
					INSERT INTO @tmpKeyValuePairs (Keyword, Value)
					VALUES (@KeyValuePair, '')
				End
			End -- </c>

			Set @StartPosition = @Delimiter1Pos + 1
		End -- </b>
	End -- </a>

	RETURN
END

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

