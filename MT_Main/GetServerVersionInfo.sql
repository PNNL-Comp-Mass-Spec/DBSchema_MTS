/****** Object:  StoredProcedure [dbo].[GetServerVersionInfo] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE GetServerVersionInfo
/****************************************************
** 
**	Desc: Returns the version numbers of the current instance of Sql Server
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	07/15/2006
**    
*****************************************************/
(
	@VersionMajor int = 0 OUTPUT,
	@VersionMinor int = 0 OUTPUT,
	@VersionBuild int = 0 OUTPUT,
	@ServicePack varchar(24)='' OUTPUT
)
As
	Set nocount on
	
	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	-- Clear the outputs
	Set @VersionMajor = 0
	Set @VersionMinor = 0
	Set @VersionBuild = 0
	Set @ServicePack = ''
	
	Declare @VersionText varchar(128)

	Declare @VersionMajorText varchar(128)
	Declare @VersionMinorText varchar(128)
	Declare @VersionBuildText varchar(128)
	
	Declare @DotLoc1 int
	Declare @DotLoc2 int
	Declare @DotLoc3 int
	
	Set @DotLoc1 = 0
	Set @DotLoc2 = 0
	Set @DotLoc3 = 0
	
	-- Retrieve the product version
	-- Should be similar to 8.00.2039 on Sql Server 2000
	-- Should be similar to 9.00.2047.00 for Sql Server 2005
	Set @VersionText = Convert(varchar(128), SERVERPROPERTY('ProductVersion'))

	Set @DotLoc1 = CharIndex('.', @VersionText)
	
	If @DotLoc1 > 0
		Set @DotLoc2 = CharIndex('.', @VersionText, @DotLoc1+1)

	If @DotLoc2 > 0
		Set @DotLoc3 = CharIndex('.', @VersionText, @DotLoc2+1)
	
	If @DotLoc1 > 0
	Begin
		If @DotLoc1 > 1
		Begin
			Set @VersionMajorText = Left(@VersionText, @DotLoc1-1)

			If @DotLoc2 > @DotLoc1
			Begin
				Set @VersionMinorText = SubString(@VersionText, @DotLoc1 + 1, @DotLoc2 - @DotLoc1 - 1)

				If @DotLoc3 > @DotLoc2
					Set @VersionBuildText = SubString(@VersionText, @DotLoc2 + 1, @DotLoc3 - @DotLoc2 - 1)
				Else
					Set @VersionBuildText = SubString(@VersionText, @DotLoc2 + 1, Len(@VersionText))
					
			End
			Else
				Set @VersionMinorText = SubString(@VersionText, @DotLoc1 + 1, Len(@VersionText))
			
		End
		Else
			Set @VersionMajorText = @VersionText


		If IsNumeric(@VersionMajorText) = 1
			Set @VersionMajor = Convert(float, @VersionMajorText)

		If IsNumeric(@VersionMinorText) = 1
			Set @VersionMinor = Convert(float, @VersionMinorText)

		If IsNumeric(@VersionBuildText) = 1
			Set @VersionBuild = Convert(float, @VersionBuildText)

		Set @ServicePack = Convert(varchar(24), SERVERPROPERTY('ProductLevel'))
	
	End
	

Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[GetServerVersionInfo] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetServerVersionInfo] TO [MTS_DB_Lite] AS [dbo]
GO
