/****** Object:  StoredProcedure [dbo].[ConvertListToWhereClause]    Script Date: 08/14/2006 20:23:11 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.ConvertListToWhereClause
/****************************************************
**	Desc:  Converts a list of entries to a proper SQL Where clause 
**  containing a mix of Where xx In ('A','B') and Where xx Like ('C%') statements
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 4/7/2004
**			  9/23/2004 grk - replaced ORF with Entry
**    
*****************************************************/
	@entryList varchar(7000) = '',								-- Comma-separated list of values
	@ColumnName varchar(255) = 'MyColumn',						-- Column for which the Where statements will apply
	@entryListWhereClause varchar(8000) = '' output,
	@message varchar(512) = '' output,
	@listSeparator char(1) = ',',								-- Default is a comma
	@quoteCharacter char(1) = '''',								-- Default is a single quote
	@wildcardSymbol char(1) = '%'								-- Default is a percent sign
As
	set nocount on

	declare @myError int
	set @myError = 0

	set @message = ''
	declare @result int

	---------------------------------------------------
	-- Add single quotes around each Entry in @entryList
	---------------------------------------------------
	Declare @entryListQuoted varchar(8000)	
	Exec QuoteNameList @entryList, @entryListQuoted = @entryListQuoted OUTPUT

	---------------------------------------------------
	-- Now examine each entry in @entryListQuoted to see if it contains @wildcardSymbol
	-- If it does, add to @sqlLikeClause
	-- If not, add to @sqlInClause
	---------------------------------------------------

	Declare @sqlInClause varchar(8000)	
	Declare @sqlLikeClause varchar(8000)	
	
	Declare @singleEntry varchar(255)
	Declare @sepLoc int

	Set @sqlInClause = ''
	Set @sqlLikeClause = ''
	
	While Len(@entryListQuoted) > 0
	Begin
		Set @sepLoc = CharIndex(@listSeparator, @entryListQuoted)
		If @sepLoc = 0		
		 Begin
			-- No list separator found
			Set @singleEntry = @entryListQuoted
			Set @entryListQuoted = ''
		 End
		Else
		 Begin
			-- List separator found
			Set @singleEntry = SubString(@entryListQuoted, 1, @sepLoc-1)
			Set @entryListQuoted = LTrim(SubString(@entryListQuoted, @sepLoc+1, Len(@entryListQuoted) - @sepLoc))
		 End

		Set @singleEntry = LTrim(RTrim(@singleEntry))
		If CharIndex(@wildcardSymbol, @singleEntry) > 0
		 Begin
			-- Wildchard character is present
			If Len(@sqlLikeClause) > 0
				Set @sqlLikeClause = @sqlLikeClause + ' OR '
			Set @sqlLikeClause = @sqlLikeClause + @ColumnName + ' LIKE ' + @singleEntry
		 End
		Else
		 Begin
			-- No wildcard character
			If Len(@sqlInClause) > 0
				Set @sqlInClause = @sqlInClause + ', '
			Set @sqlInClause = @sqlInClause + @singleEntry
		 End
	End

	If Len(@sqlInClause) > 0
		Set @entryListWhereClause = @ColumnName + ' IN (' + @sqlInClause + ')'
	Else
		Set @entryListWhereClause = ''
		
	If Len(@sqlLikeClause) > 0
	Begin
		If Len(@entryListWhereClause) > 0
			Set @entryListWhereClause = @entryListWhereClause + ' OR '
		Set @entryListWhereClause = @entryListWhereClause + @sqlLikeClause
	End
	
	
Done:
	return @myError



GO
GRANT EXECUTE ON [dbo].[ConvertListToWhereClause] TO [DMS_SP_User]
GO
GRANT EXECUTE ON [dbo].[ConvertListToWhereClause] TO [MTUser]
GO
