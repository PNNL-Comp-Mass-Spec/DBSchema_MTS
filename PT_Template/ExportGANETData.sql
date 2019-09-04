/****** Object:  StoredProcedure [dbo].[ExportGANETData] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure [dbo].[ExportGANETData]
/****************************************************
**
**	Desc:
**		Optionally calls MT_Main..GetGANETFolderPaths, then calls
**      ExportGANETPeptideFile to create the Peptide file,
**		then creates the Job Stats file(s)
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	04/08/2005
**			05/28/2005 mem - Switched to using @TaskID and T_NET_Update_Task_Job_Map to define the jobs to process
**						   - Added parameter @ResultsFolderPath
**			11/23/2005 mem - Added brackets around @dbName as needed to allow for DBs with dashes in the name
**			07/03/2006 mem - Now using dbo.udfCombinePaths() to combine paths
**			07/05/2006 mem - Now calling ValidateFolderExists to validate that the output and results folders exist
**			03/13/2010 mem - Added parameter @ObsNETsFileName and made @SourceFolderPath and @ResultsFolderPath output parameters
**          08/14/2019 mem - Added parameter @skipXpCmdShell
**
*****************************************************/
(
	@TaskID int,											-- Corresponds to task in T_NET_Update_Task
	@SourceFolderPath varchar(256) = '',					-- Path to folder containing source data; if blank, then will look up path in MT_Main (e.g. I:\GA_Net_Xfer\Out\PT_Shewanella_ProdTest_A123\)
	@ResultsFolderPath varchar(256) = '',					-- Path to folder containing the results; if blank, then will look up path in MT_Main (e.g. I:\GA_Net_Xfer\In\PT_Shewanella_ProdTest_A123\)
	@SourceFileName varchar(256) = '' output,				-- Source file name
	@ResultsFileName varchar(256) = '' output,				-- Results file name
	@PredNETsFileName varchar(256) = '' output,				-- Predict NETs results file name
	@ObsNETsFileName varchar(256) = '' output,				-- Observed NETs results file name
	@jobStatsFileName varchar(256) = 'jobStats.txt',
	@exportJobStatsFileOnly tinyint = 0,					-- When 1, then only creates the Job Stats file(s) and does not call ExportGANETPeptideFile
    @skipXpCmdShell Tinyint = 0,
	@message varchar(256)='' OUTPUT
)
As
	Set nocount on

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	set @message = ''

	declare @FirstJob int
	declare @LastJob int
	declare @JobFileSuffix varchar(1024)

	declare @SourceFolderPathBase varchar(256)
	declare @ResultsFolderPathBase varchar(256)
	declare @DBName varchar(128)

	declare @JobStatsFilePath varchar(512)

	declare @BcpSql nvarchar(2000)
	declare @cmd nvarchar(4000)
	declare @result int

	Set @DBName = DB_Name()

    Set @exportJobStatsFileOnly = IsNull(@exportJobStatsFileOnly, 0)
    Set @skipXpCmdShell = IsNull(@skipXpCmdShell, 0)


	If Len(IsNull(@SourceFolderPath, '')) = 0 OR Len(IsNull(@ResultsFolderPath, '')) = 0
	Begin
		--------------------------------------------------------------
		-- Get the file and folder paths
		--------------------------------------------------------------
		--
		set @SourceFolderPathBase = ''
		set @ResultsFolderPathBase = ''

		exec @myError = MT_Main..GetGANETFolderPaths
											0,	-- @clientPerspective = false
											'', -- @SourceFileName
											@SourceFolderPathBase output,
											'', -- @ResultsFileName
											@ResultsFolderPathBase output,
											'', -- @PredNETsFileName
											@message  output
		if @myError <> 0
			Goto Done

		Set @SourceFolderPath = dbo.udfCombinePaths(@SourceFolderPathBase, @DBName + '\')
		Set @ResultsFolderPath = dbo.udfCombinePaths(@ResultsFolderPathBase,  @DBName + '\')
	End

	---------------------------------------------------
	-- Lookup the first and last job in T_NET_Update_Task_Job_Map
	---------------------------------------------------
	SELECT @FirstJob = Min(Job)
	FROM T_NET_Update_Task_Job_Map
	WHERE Task_ID = @TaskID

	SELECT @LastJob = Max(Job)
	FROM T_NET_Update_Task_Job_Map
	WHERE Task_ID = @TaskID

	If @FirstJob Is Null OR @LastJob Is Null
	Begin
		Set @myError = 60000
		Set @message = 'No jobs were found in T_NET_Update_Task_Job_Map for Task_ID ' + Convert(varchar(9), @TaskID)
		Goto Done
	End

	---------------------------------------------------
	-- Assure that the output folder exists
	-- Try to create it if it does not exist
	---------------------------------------------------
	exec @myError = ValidateFolderExists @SourceFolderPath, @CreateIfMissing = 1, @message = @message output

	If @myError <> 0
	Begin
		if Len(IsNull(@message, '')) = 0
			Set @message = 'Error verifying that the NET Processing output folder exists: ' + IsNull(@SourceFolderPath, '??')
		else
			Set @message = @message + ' (NET Processing folder)'

		Set @myError = 60001
		Goto Done
	End

	---------------------------------------------------
	-- Assure that the results folder exists
	-- Try to create it if it does not exist
	---------------------------------------------------
	exec @myError = ValidateFolderExists @ResultsFolderPath, @CreateIfMissing = 1, @message = @message output

	If @myError <> 0
	Begin
		if Len(IsNull(@message, '')) = 0
			Set @message = 'Error verifying that the NET Processing results folder exists: ' + IsNull(@ResultsFolderPath, '??')
		else
			Set @message = @message + ' (NET Processing folder)'

		Set @myError = 60002
		Goto Done
	End

	---------------------------------------------------
	-- Write the output files
	-- Define @SourceFileName, @ResultsFileName, @PredNETsFileName, and @ObsNETsFileName based on @FirstJob and @Last Job
	---------------------------------------------------

	If @LastJob = @FirstJob
		Set @JobFileSuffix = '_Job' + Convert(varchar(12), @FirstJob) + '.txt'
	Else
		Set @JobFileSuffix = '_Jobs' + Convert(varchar(12), @FirstJob) + '-' + Convert(varchar(12), @LastJob) + '.txt'

	Set @SourceFileName = 'peptideGANET' + @JobFileSuffix
	Set @ResultsFileName = 'JobGANETs' + @JobFileSuffix
	Set @PredNETsFileName = 'PredictGANETs' + @JobFileSuffix
	Set @ObsNETsFileName = 'ObservedNETsAfterRegression' + @JobFileSuffix
	Set @jobStatsFileName = 'jobStats' + @JobFileSuffix

	--------------------------------------------------------------
	-- Record the folder path and file names in T_NET_Update_Task
	--------------------------------------------------------------
	UPDATE T_NET_Update_Task
	SET Output_Folder_Path = @SourceFolderPath,
		Out_File_Name = @SourceFileName,
		Results_Folder_Path = @ResultsFolderPath,
		Results_File_Name = @ResultsFileName,
		PredictNETs_File_Name = @PredNETsFileName,
		ObservedNETs_File_Name = @ObsNETsFileName
	WHERE Task_ID = @TaskID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	--------------------------------------------------------------
	-- Always use the Peak Apex time when exporting the peptide data
	--------------------------------------------------------------
	Declare @UsePeakApex tinyint
	set @UsePeakApex = 1

	--------------------------------------------------------------
	-- Possibly write out the peptides file
	--------------------------------------------------------------
	--
	If @exportJobStatsFileOnly= 0 And @skipXpCmdShell = 0
	Begin
		Exec @myError = ExportGANETPeptideFile @SourceFolderPath, @SourceFileName, @TaskID, @UsePeakApex, @message Output
		--
		if @myError <> 0
			Goto Done
	End

	--------------------------------------------------------------
	-- Write out the job stats file
	--------------------------------------------------------------

	/**************************************************************************
	** xp_cmdshell note
	**
	** When user MTSProc calls this SP, xp_cmdshell will run under the
	** xp_cmdshell Proxy Account.  This account must be created
	** by a system admin using:
	**
	** EXEC sp_xp_cmdshell_proxy_account 'PNL\MTSProc', 'TypePasswordHere';
	**
	** Additionally, when the password for MTSProc changes, this
	** command must be run to update the password
	**
	**************************************************************************/

	--
	Set @JobStatsFilePath = '"' + dbo.udfCombinePaths(@SourceFolderPath, @jobStatsFileName) + '"'

	-- Use a SQL query against a view linked to T_NET_Update_Task_Job_Map, along with a Where clause
	Set @BcpSql = ''
	Set @BcpSql = @BcpSql + ' SELECT AJ.* FROM [' + @DBName + '].dbo.V_MSMS_Analysis_Jobs AJ INNER JOIN'
	Set @Bcpsql = @BcpSql + ' [' + @DBName + '].dbo.T_NET_Update_Task_Job_Map TJM ON AJ.Job = TJM.Job'
	Set @BcpSql = @BcpSql + ' WHERE TJM.Task_ID = ' + Convert(varchar(9), @TaskID)
	Set @cmd = 'bcp "' + @BcpSql + '" queryout ' + @JobStatsFilePath + ' -c -T'
	--
    If @skipXpCmdShell = 0
    Begin
	    EXEC @result = master..xp_cmdshell @cmd, NO_OUTPUT
	    Set @myError = @result
    End
	--
	if @myError <> 0
	begin
		-- Error writing file
		Set @message = 'Error exporting data from V_MSMS_Analysis_Jobs to ' + @SourceFolderPath
		goto done
	end

	SET @message = 'Complete ExportGANET'

Done:
	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[ExportGANETData] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ExportGANETData] TO [MTS_DB_Lite] AS [dbo]
GO
