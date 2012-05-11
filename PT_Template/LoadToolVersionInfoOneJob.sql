/****** Object:  StoredProcedure [dbo].[LoadToolVersionInfoOneJob] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.LoadToolVersionInfoOneJob
/****************************************************
**
**	Desc:	Loads Tool version info file(s) for specified tool in specified folder
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	12/30/2011 mem - Initial Version
**
*****************************************************/
(
	@Job int,
	@AnalysisToolName varchar(128),						-- Sequest, Masic_Finnigan, XTandem, MSGF, etc.
	@StoragePathResults varchar(512),					-- Path to the folder to look for the Tool version info file, e.g. Tool_Version_Info_MSGF.txt
	@message varchar(255) = '' OUTPUT
)
AS
	Set nocount on

	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	Declare @ErrorPrimaryTool int = 0
	Declare @ErrorDataExtractor int = 0
	Declare @ErrorMSGF int = 0
	
	Declare @ToolVersionInfo varchar(512) = ''
	Declare @ToolVersionInfoDataExtractor varchar(512) = ''
	Declare @ToolVersionInfoMSGF varchar(512) = ''
	
	-----------------------------------------------
	-- Clear the outputs
	-----------------------------------------------
	Set @message = ''

	-----------------------------------------------
	-- Load the tool version info for the primary tool, plus the DataExtractor and MSGF
	-- Tool version info files may not actually be present
	-----------------------------------------------
	
	exec @ErrorPrimaryTool = LoadToolVersionInfo @AnalysisToolName, @StoragePathResults, @Job, @ToolVersionInfo output, @message output, @RaiseErrorIfFileNotFound=1
	Set @ToolVersionInfo = IsNull(@ToolVersionInfo, '')
	
	If @AnalysisToolName Like 'MASIC%'
	Begin
		Set @ToolVersionInfoDataExtractor = ''
		Set @ToolVersionInfoMSGF = ''
	End
	Else
	Begin
		exec @ErrorDataExtractor = LoadToolVersionInfo 'DataExtractor', @StoragePathResults, @Job, @ToolVersionInfoDataExtractor output, @message output, @RaiseErrorIfFileNotFound=1
		Set @ToolVersionInfoDataExtractor = IsNull(@ToolVersionInfoDataExtractor, '')

		exec @ErrorMSGF = LoadToolVersionInfo 'MSGF', @StoragePathResults, @Job, @ToolVersionInfoMSGF output, @message output, @RaiseErrorIfFileNotFound=1
		Set @ToolVersionInfoMSGF = IsNull(@ToolVersionInfoMSGF, '')
	End

	
	MERGE T_Analysis_ToolVersion as target
	USING (SELECT @Job, @ToolVersionInfo, @ToolVersionInfoDataExtractor, @ToolVersionInfoMSGF
           ) AS Source (Job, Tool_Version, DataExtractor_Version, MSGF_Version)
            ON (target.Job = source.Job)
    WHEN Matched THEN
		UPDATE set 
	       Job = source.Job, 
	       Tool_Version = source.Tool_Version, 
	       DataExtractor_Version = source.DataExtractor_Version,
	       MSGF_Version = source.MSGF_Version,
	       Entered = GetDate()
    WHEN Not Matched THEN
	INSERT (Job, Tool_Version, DataExtractor_Version, MSGF_Version, Entered)
    VALUES (source.Job, source.Tool_Version, source.DataExtractor_Version, source.MSGF_Version, GetDate())
	;
		
	
	If @ErrorPrimaryTool <> 0 Or @ErrorDataExtractor <> 0 Or @ErrorMSGF <> 0
	Begin
		Set @message = 'Tool version info not loaded for job ' + Convert(varchar(12), @Job)
	
		If @ErrorPrimaryTool <> 0
			Set @message = @message  + ', tool ' + @AnalysisToolName
			
		If @ErrorDataExtractor <> 0
			Set @message = @message  + ', tool ' + 'DataExtractor'
			
		If @ErrorMSGF <> 0
			Set @message = @message  + ', tool ' + 'MSGF'
		
		-- Only post a warning if no tool version info was loaded for any of the tools
		If @ErrorPrimaryTool <> 0 And @ErrorDataExtractor <> 0 And @ErrorMSGF <> 0
			Exec PostLogEntry 'Warning', @message, 'LoadToolVersionInfoPeptideHitJob'
		
	End

	-----------------------------------------------
	-- Exit
	-----------------------------------------------
Done:
	Return @myError


GO
