SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CleanupTrueFalseParameter]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[CleanupTrueFalseParameter]
GO

CREATE PROCEDURE dbo.CleanupTrueFalseParameter
/****************************************************
**
**	Desc: 
**		Makes sure @TrueFalseParameter contains 'true' or 'false' (lowercase)
**		If @TrueFalseParameter contains a number, then changes to 'false' if zero, 'true' otherwise
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**		@TrueFalseParameter			-- Parameter to examine
**		@DefaultIsTrue				-- If 1, then default is 'true', otherwise, is 'false'
**
**		Auth: mem
**		Date: 10/23/2004
**    
*****************************************************/
	@TrueFalseParameter varchar(32) = 'False' OUTPUT,
	@DefaultIsTrue tinyint = 0
AS
	set nocount on

	declare @myError int
	set @myError = 0

	declare @DefaultValue varchar(32)
	
	If IsNull(@DefaultIsTrue, 0) = 0
		Set @DefaultValue = 'false'
	else
		Set @DefaultValue = 'true'

	-- Trim and lowercase @TrueFalseParameter, and remove any leading or trailing quotation marks
	Set @TrueFalseParameter = Lower(LTrim(RTrim(IsNull(@TrueFalseParameter, @DefaultValue))))
	Set @TrueFalseParameter = REPLACE(@TrueFalseParameter, '''', '')

	If IsNumeric(@TrueFalseParameter) = 1
	Begin
		If @TrueFalseParameter = '0'
			Set @TrueFalseParameter = 'false'
		Else
			Set @TrueFalseParameter = 'true'
	End
	
	If @TrueFalseParameter = 't'
		Set @TrueFalseParameter = 'true'
	else
		If @TrueFalseParameter = 'f'
			Set @TrueFalseParameter = 'false'
		
	If @TrueFalseParameter <> 'true' And @TrueFalseParameter <> 'false'
		Set @TrueFalseParameter = @DefaultValue
	
	Return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[CleanupTrueFalseParameter]  TO [DMS_SP_User]
GO

GRANT  EXECUTE  ON [dbo].[CleanupTrueFalseParameter]  TO [MTUser]
GO

GRANT  EXECUTE  ON [dbo].[CleanupTrueFalseParameter]  TO [pogo\MTS_DB_Dev]
GO

GRANT  EXECUTE  ON [dbo].[CleanupTrueFalseParameter]  TO [MTS_DB_Lite]
GO

