
ALTER FUNCTION dbo.udfGetFileNameFromPath
/****************************************************	
**	Looks for the final \ in @FilePath, then returns the filename after the slash
**  If no slash in @FilePath, or if no text after the slash, then returns an empty string
**
**	Auth:	mem
**	Date:	10/09/2006
**  
****************************************************/
(
	@FilePath varchar(4096)
)
RETURNS varchar(2048)
AS
BEGIN
	Declare @SlashLoc int
	Declare @PathLength int
	
	Declare @FileName varchar(2048)
	Set @FileName = ''
	
	Set @FilePath = LTrim(RTrim(IsNull(@FilePath, '')))
	
	Set @PathLength = Len(@FilePath)
	If @PathLength > 0
	Begin
		Set @SlashLoc = CharIndex('\', reverse(@FilePath))
		If @SlashLoc > 0 
		Begin
			Set @SlashLoc = @PathLength - @SlashLoc + 1
			If @SlashLoc < @PathLength
			Begin
				Set @FileName = Substring(@FilePath, @SlashLoc+1, @PathLength)
			End
		End
	End
		
	RETURN @FileName
END
