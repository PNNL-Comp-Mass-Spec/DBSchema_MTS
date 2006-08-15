/****** Object:  StoredProcedure [dbo].[NextField] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCedure NextField
/****************************************************
**
**	Desc: Parses off and returns next field from string.
**        Intended to be called repeatedly to get all
**        fields, 'curPos' value remembers where parsing
**        left off - caller must preserve its contents.
**
**	Return values: 0: end of line not yet encountered
**
**	Parameters:
**		@line		string to extract next field from
**		@delimiter	delimiter character
**	    @curPos		postion to start looking for field
**	    @field		contents of field
**
**		Auth: grk
**		Date: 12/13/2000
**    
*****************************************************/
	@line varchar(1000),
	@delimiter char(1),
    @curPos int output,
    @field varchar(255) output
As
	declare @EndOfField int
	declare @EOL int
	set @EOL = 0
	
	-- find position of delimiter
	--
	set @EndOfField = charindex(@delimiter, @line, @curPos)
	-- if delimiter not found, field contains rest of string
	-- and end-of-line condition is set
	--
	if @EndOfField = 0
	begin
		set @EndOfField = LEN(@line) + 1
		set @EOL = 1
	end
	
	-- extract field based on positions
	--
	set @field = ltrim(rtrim(substring(@line, @curPos, @EndOfField - @curPos)))
--	print '-->' + @field -- debug
	-- advance current starting position beyond current field
	-- and set end-of-line condidtion if it is past the end of the line
	--
	set @curPos = @EndOfField + 1
	if @curPos > LEN(@line)
		set @EOL = 1
	return @EOL


GO
GRANT EXECUTE ON [dbo].[NextField] TO [DMS_SP_User]
GO
