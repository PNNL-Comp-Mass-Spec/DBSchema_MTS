/****** Object:  StoredProcedure [dbo].[CountSubstringInProtein] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.CountSubstringInProtein
/****************************************************
** 
**		Desc: 
**			Counts the number of times a given string is found in a
**			Protein (specified by Ref_ID)
**
**		Return values: the number of times the string was found
**			(or less, if (string length * repeats) > 8000)
** 
**		Parameters: 
**			@ref_id - used to look up Protein_Sequence in
**				T_Proteins
**			@string - sequence of amino acids to look for in
**				the protein
**		
**		Outputs: none
**
**		Auth: kal
**		Date: 7/14/2003
**			  9/18/2004 mem - Replaced ORF references with Protein references
*****************************************************/
	(
		@ref_id int,
		@string varchar(8000)
	)
AS
	SET NOCOUNT ON
	-----------------------------------------------------------
	--Basic strategy: create a pattern of the form %@string%@string%@string%
	--and use the patindex function.  As long as this continues to work, append
	--@string% to the current search and try again.
	-----------------------------------------------------------
	
	declare @origString varchar(8000)
	set @origString = @string
	
	declare @count int
	set @count = 0
	
	set @string = '%' + @string + '%'
	
	declare @index int
	
	--Because Protein_Sequence is a text field, it's necessary to use patindex
	--as opposed to charindex.  Also, a select must be performed each time, 
	--since there's no way to have a local text variable
	SELECT @index = patindex(@string, Protein_Sequence)
	FROM T_Proteins
	WHERE Ref_ID = @ref_id
	
	--since @string can be at most ~8000 characters, this procedure could give the
	--wrong result if @string is quite long and occurs many times in the Protein
	--however, it's necessary to return if the string gets this long, or an endless
	--loop would result 
	--(patindex returns 0 if the pattern wasn't found)
	while (@index <> 0) AND len(@string) < 8000
	begin
		set @count = @count + 1
		
		--since the pattern was found, append another copy of the given string
		--and search again
		set @string = @string + @origString + '%'
		SELECT @index = patindex(@string, Protein_Sequence)
		FROM T_Proteins
		WHERE Ref_ID = @ref_id
	end
	
	RETURN @count


GO
GRANT VIEW DEFINITION ON [dbo].[CountSubstringInProtein] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[CountSubstringInProtein] TO [MTS_DB_Lite]
GO
