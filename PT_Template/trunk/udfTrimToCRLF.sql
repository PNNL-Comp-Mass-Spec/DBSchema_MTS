SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[udfTrimToCRLF]') and xtype in (N'FN', N'IF', N'TF'))
drop function [dbo].[udfTrimToCRLF]
GO


CREATE FUNCTION dbo.udfTrimToCRLF
/****************************************************	
**	Looks for a carriage return and/or line feed in the given string
**  and trims the string to end just before the first CR or LF
**
**	Auth:	mem
**	Date:	11/30/2005
**			06/06/2006 - Optimized the code to only call the CharIndex function twice
**  
****************************************************/
(
	@TextToTrim varchar(8000)
)
RETURNS varchar(8000)
AS
BEGIN
	Declare @CharLoc int

	-- Look char(10) in @TextToTrim
	Set @CharLoc = CharIndex(char(10), @TextToTrim)
	If @CharLoc > 0
		Set @TextToTrim = Substring(@TextToTrim, 1, @CharLoc - 1)
		
	-- Look char(13) in @TextToTrim
	Set @CharLoc = CharIndex(char(13), @TextToTrim)
	If @CharLoc > 0
		Set @TextToTrim = Substring(@TextToTrim, 1, @CharLoc - 1)
		
	RETURN  @TextToTrim
END


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

