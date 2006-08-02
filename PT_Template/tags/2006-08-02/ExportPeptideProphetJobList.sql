SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ExportPeptideProphetJobList]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ExportPeptideProphetJobList]
GO


CREATE Procedure dbo.ExportPeptideProphetJobList
/****************************************************
**
**	Desc: 
**		Optionally calls MT_Main..GetPeptideProphetFolderPaths, then creates
**		the Peptide Prophet Job List file for the given Task_ID
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	07/05/2006
**    
*****************************************************/
(
	@TaskID int,											-- Corresponds to task in T_Peptide_Prophet_Task
	@clientPerspective tinyint = 1,							-- 0 means running SP from local server; 1 means running SP from client
	@TransferFolderPath varchar(256) = '',					-- Path to folder containing source data; if blank, then will look up path in MT_Main
	@JobListFileName varchar(256) = '' output,			
	@ResultsFileName varchar(256) = '' output,					
	@message varchar(256)='' OUTPUT
)
AS
	Set nocount on
	
	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	set @message = ''
	
	declare @FirstJob int
	declare @LastJob int
	declare @JobFileSuffix varchar(1024)

	declare @TransferFolderPathBase varchar(256)
	declare @DBName varchar(128)

	declare @ExportFilePath varchar(512)

	declare @BcpSql nvarchar(3000)
	declare @cmd nvarchar(4000)
	declare @result int

	Set @DBName = DB_Name()

	If Len(IsNull(@TransferFolderPath, '')) = 0
	Begin
		--------------------------------------------------------------
		-- Get the file and folder paths
		--------------------------------------------------------------
		--
		exec @myError = MT_Main..GetPeptideProphetFolderPaths
											@clientPerspective,
											@TransferFolderPath output,
											'', -- @JobListFileName
											'', -- @ResultsFileName
											@message = @message output
		if @myError <> 0
			Goto Done

		Set @TransferFolderPath = dbo.udfCombinePaths(@TransferFolderPath, @DBName + '\')
	End

	---------------------------------------------------
	-- Lookup the first and last job in T_Peptide_Prophet_Task_Job_Map
	---------------------------------------------------
	SELECT @FirstJob = Min(Job)
	FROM T_Peptide_Prophet_Task_Job_Map
	WHERE Task_ID = @TaskID

	SELECT @LastJob = Max(Job)
	FROM T_Peptide_Prophet_Task_Job_Map
	WHERE Task_ID = @TaskID
	
	If @FirstJob Is Null OR @LastJob Is Null
	Begin
		Set @myError = 60000
		Set @message = 'No jobs were found in T_Peptide_Prophet_Task_Job_Map for Task_ID ' + Convert(varchar(9), @TaskID) 
		print @message
		Goto Done
	End

	---------------------------------------------------
	-- Assure that the output folder exists
	-- Try to create it if it does not exist
	---------------------------------------------------
	exec @myError = ValidateFolderExists @TransferFolderPath, @CreateIfMissing = 1, @message = @message output
	
	If @myError <> 0
	Begin
		if Len(IsNull(@message, '')) = 0
			Set @message = 'Error verifying that the Peptide Prophet transfer folder exists: ' + IsNull(@TransferFolderPath, '??')
		else
			Set @message = @message + ' (Peptide Prophet transfer folder)'
			
		Set @myError = 60001
		Goto Done
	End
	
	---------------------------------------------------
	-- Write the output file
	-- Need to define @JobListFileName and @ResultsFileName based on @FirstJob and @Last Job
	---------------------------------------------------

	If @LastJob = @FirstJob
		Set @JobFileSuffix = '_Job' + Convert(varchar(12), @FirstJob) + '.txt'
	Else
		Set @JobFileSuffix = '_Jobs' + Convert(varchar(12), @FirstJob) + '-' + Convert(varchar(12), @LastJob) + '.txt'
		
	Set @JobListFileName = 'PepProphetTaskList' + @JobFileSuffix
	Set @ResultsFileName = 'PepProphetTaskResults' + @JobFileSuffix

	--------------------------------------------------------------
	-- Record the folder path and file names in T_Peptide_Prophet_Task
	--------------------------------------------------------------
	UPDATE T_Peptide_Prophet_Task
	SET Transfer_Folder_Path = @TransferFolderPath,
		JobList_File_Name = @JobListFileName,
		Results_File_Name = @ResultsFileName
	WHERE Task_ID = @TaskID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	--------------------------------------------------------------
	-- Write out the job info
	--------------------------------------------------------------
	--
	Set @ExportFilePath = '"' + dbo.udfCombinePaths(@TransferFolderPath, @JobListFileName) + '"'

	-- Use a SQL query against T_Analysis_Description linked to T_Peptide_Prophet_Task_Job_Map, along with a Where clause
	Set @BcpSql = ''

	Set @BcpSql = @BcpSql + ' SELECT TAD.Job, dbo.udfCombinePaths(dbo.udfCombinePaths(dbo.udfCombinePaths(dbo.udfCombinePaths('
	Set @BcpSql = @BcpSql +        ' TAD.Vol_Client, TAD.Storage_Path), TAD.Dataset_Folder), TAD.Results_Folder), TAD.Dataset + ''_syn.txt'') AS Synopsis_File_Path'
	Set @BcpSql = @BcpSql + ' FROM [' + @DBName + '].dbo.T_Peptide_Prophet_Task_Job_Map PPT INNER JOIN'
	Set @BcpSql = @BcpSql +      ' [' + @DBName + '].dbo.T_Analysis_Description TAD ON PPT.Job = TAD.Job'
	Set @BcpSql = @BcpSql + ' WHERE PPT.Task_ID = ' + Convert(varchar(9), @TaskID)
	Set @BcpSql = @BcpSql + ' ORDER BY TAD.Job'
	
	Set @cmd = 'bcp "' + @BcpSql + '" queryout ' + @ExportFilePath + ' -c -T'
	print @cmd
	--
	EXEC @result = master..xp_cmdshell @cmd, NO_OUTPUT 
	Set @myError = @result
	--
	if @myError <> 0
	begin
		-- Error writing file
		Set @message = 'Error exporting data from T_Peptide_Prophet_Task_Job_Map and T_Analysis_Description to ' + @ExportFilePath
		goto done
	end
	
	SET @message = 'Complete ExportPeptideProphetJobList'
	
Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

