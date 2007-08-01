/****** Object:  UserDefinedFunction [dbo].[udfPeakMatchingPathForMDID] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create FUNCTION dbo.udfPeakMatchingPathForMDID
/****************************************************	
**	Constructs the path to the peak matching results
**  for the given MD_ID value
**
**	Date: 05/12/2004
**	Author: mem
**
**	Updated: 05/14/2004 mem - Now returning path as a valid URL rather than as a UNC path
**			 06/01/2004 mem - Now including Index.html at the end of the URL
**  
****************************************************/
(
	@MDID int
)
RETURNS varchar(1024)
AS
BEGIN

	-- Set the following to 0 to return a UNC path; set to 1 to return a URL
	Declare @URLFormat tinyint
	Set @URLFormat = 1
	
	Declare	@PeakMatchingResultsPath varchar(1024)

	Declare @OutputFolderName varchar(950)
	Set @OutputFolderName = ''
	
	If @URLFormat = 0
	Begin

		-- Look up the Peak matching results path from MT_Main
		SELECT TOP 1 @PeakMatchingResultsPath = Client_Path
		FROM MT_Main.dbo.T_Folder_Paths
		WHERE [Function] = 'Peak Matching Results'

		If Len(IsNull(@PeakMatchingResultsPath, '')) = 0
			Set @PeakMatchingResultsPath = '\\Pogo\MTD_Peak_Matching\Results\'

		Set @PeakMatchingResultsPath = @PeakMatchingResultsPath + DB_NAME()

		-- Look up the MDID value in T_Peak_Matching_Task
		SELECT TOP 1 @OutputFolderName = IsNull(Output_Folder_Name, '')
		FROM T_Peak_Matching_Task
		WHERE (MD_ID = @MDID)
		
		If Len(@OutputFolderName) > 0
			Set @PeakMatchingResultsPath = @PeakMatchingResultsPath + '\' + @OutputFolderName
			
	End
	Else
	Begin

		-- Look up the Peak matching results path from MT_Main
		SELECT TOP 1 @PeakMatchingResultsPath = Client_Path
		FROM MT_Main.dbo.T_Folder_Paths
		WHERE [Function] = 'Peak Matching Results Website'

		If Len(IsNull(@PeakMatchingResultsPath, '')) = 0
			Set @PeakMatchingResultsPath = 'http://Pogo/pm/Results/'

		Set @PeakMatchingResultsPath = @PeakMatchingResultsPath + DB_NAME() + '/'

		-- Look up the MDID value in T_Peak_Matching_Task
		SELECT TOP 1 @OutputFolderName = IsNull(Output_Folder_Name, '')
		FROM T_Peak_Matching_Task
		WHERE (MD_ID = @MDID)

		If Len(@OutputFolderName) > 0
		Begin
			Set @OutputFolderName = Replace(@OutputFolderName, '\', '/')
			Set @PeakMatchingResultsPath = @PeakMatchingResultsPath + @OutputFolderName + '/Index.html'
		End

	End
	
		
	RETURN  @PeakMatchingResultsPath
END

GO
