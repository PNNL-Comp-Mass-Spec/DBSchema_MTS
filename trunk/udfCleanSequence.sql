/****** Object:  UserDefinedFunction [dbo].[udfCleanSequence] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION dbo.udfCleanSequence
/****************************************************	
**	Examines @rawSequence and returns the clean sequence
**
**	Auth:	mem
**	Date:	01/10/2006
**			03/21/2006 mem - Decreased the size of @rawSequence from varchar(8000) to varchar(1024)
**  
****************************************************/
(
	@rawSequence varchar(1024)
)
RETURNS varchar(1024)
AS
BEGIN

	Declare @seqPos int
	Declare @ln int
	Declare @ch char
	
	Declare @cleanSequence varchar(1024)

	-----------------------------------------------------------
	-- remove terminii symbols from raw sequence
	-----------------------------------------------------------
	
	set @ln = len(@rawSequence)
	if @ln > 4
	begin
		if SubString(@rawSequence, @ln-1, 1) = '.'
			set @rawSequence = left(@rawSequence, @ln-2)
		
		if SubString(@rawSequence, 2, 1) = '.'
			set @rawSequence = SubString(@rawSequence, 3, @ln-2)
	end
	
	-----------------------------------------------------------
	-- remove non-letter characters from @rawSequence
	-----------------------------------------------------------
	
	set @seqPos = 1
	set @ln = len(@rawSequence)
	set @cleanSequence = ''
	
	while @seqPos <= @ln
	begin
		-- get next char in raw sequence
		--
		set @ch = SubString(@rawSequence, @seqPos, 1)  
		
		-- if char is an amino acid, then add to clean sequence
		--
		if @ch Like '[A-Z]'
			set @cleanSequence = @cleanSequence + @ch
			
		set @seqPos = @seqPos + 1
	end
			
	Return  @cleanSequence
END


GO
