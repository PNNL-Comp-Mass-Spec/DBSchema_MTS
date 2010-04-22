/****** Object:  StoredProcedure [dbo].[CountSubstringInString] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE dbo.CountSubstringInString
/****************************************************
**
**	Desc: Find the number of times a given string occurs
**		within another
**
**	Return value: the number of times @substring is in
**		@string
**
**	Parameters:
**		@string - string to search in
**		@substring - string to search for
**		@distinct - if the instances of @substring are
**			allowed to overlap or not - 0 if no overlap
**			can happen, not 0 otherwise
**
**  Output:
**
**		Auth: kal
**		Date: 7/14/2003   
*****************************************************/
	(
		@string varchar(8000),
		@substring varchar(8000),
		@distinct int = 1
	)
AS
	SET NOCOUNT ON

declare @count int
set @count = 0

declare @index int
set @index = charindex(@substring, @string)

while @index <> 0
begin
	set @count = @count + 1
	if @distinct = 0
		set @index = charindex(@substring, @string, @index + 1)
	else
		set @index = charindex(@substring, @string, @index + len(@substring))
end

RETURN @count



GO
GRANT EXECUTE ON [dbo].[CountSubstringInString] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CountSubstringInString] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CountSubstringInString] TO [MTS_DB_Lite] AS [dbo]
GO
