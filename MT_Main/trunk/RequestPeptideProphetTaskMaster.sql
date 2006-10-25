/****** Object:  StoredProcedure [dbo].[RequestPeptideProphetTaskMaster] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE RequestPeptideProphetTaskMaster
/****************************************************
**
**	Desc:	For each database listed in T_PT_Database_List, calls the RequestPeptideProphetTask SP
**			If @TaskAvailable = 1, then exits the loop and exits this SP, returning 
**			 the parameters returned by the RequestPeptideProphetTask SP.  If @TaskAvailable = 0, 
**			 then continues calling RequestPeptideProphetTask in each database until all have been called.
**
**			If @dbName is provided, will check that DB first
**			If @restrictToDbName = 1, then only checks @dbName
**
**	Auth:	mem
**	Date:	07/05/2006
**			07/13/2006 mem - Changed VerifyUpdateEnabled call to use keyword 'Peptide_Prophet_Manager' rather than 'Peptide_DB_Update'
**
*****************************************************/
(
	@processorName varchar(128),
	@clientPerspective tinyint = 1,					-- 0 means running SP from local server; 1 means running SP from client
	@restrictToDbName tinyint = 0,					-- If 1, will only check the DB named @dbName
	@taskID int = 0 output,							-- Peptide Prophet Update Task ID
	@dbName varchar(128) = '' output,				-- if provided, will preferentially query that database first
	@TransferFolderPath varchar(256) = '' output,	-- Source file folder path
	@JobListFileName varchar(256) = '' output,		-- Source file name
	@ResultsFileName varchar(256) = ''output,		-- Results file name
	@taskAvailable tinyint = 0 output,				-- 1 if a task is available; otherwise 0
	@message varchar(512) = '' output
)
As
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @done int
	declare @ActivityRowCount int
	declare @SPRowCount int
	declare @UpdateEnabled tinyint

	set @done = 0
	set @ActivityRowCount = 0
	set @SPRowCount = 0
	
	-- Note: @S needs to be unicode (nvarchar) for compatibility with sp_executesql
	declare @S nvarchar(1024),
			@CurrentDB varchar(255),
			@UniqueRowIDCurrent int,
			@SPToExec varchar(255),
			@PreferredDBName varchar(255),
			@TransferFolderPathBase varchar(255)

	set @S = ''
	set @CurrentDB = ''
	set @UniqueRowIDCurrent = 0
	set @SPToExec = ''
	set @PreferredDBName = IsNull(@dbName, '')
	set @message = ''
		
	---------------------------------------------------
	-- Clear the output arguments
	---------------------------------------------------
	set @taskID = 0
	set @dbName = ''
	set @TransferFolderPath = ''
	set @TransferFolderPathBase = ''
	set @JobListFileName = ''
	set @ResultsFileName = ''
	set @taskAvailable = 0

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled 'Peptide_Prophet_Manager', 'RequestPeptideProphetTaskMaster', @AllowPausing = 0, @PostLogEntryIfDisabled = 0, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done

	---------------------------------------------------
	-- Create a temporary table to hold list of databases to process
	---------------------------------------------------
	CREATE TABLE #TmpDBsToProcess (
		UniqueRowID int identity(1,1),
		Database_Name varchar(128)
	) 

	-- Add an index to #TmpDBsToProcess on column UniqueRowID
	CREATE CLUSTERED INDEX #IX_TmpDBsToProcess ON #TmpDBsToProcess(UniqueRowID)

	---------------------------------------------------
	-- Populate the temporary table with list of peptide
	-- databases that are not deleted
	---------------------------------------------------
	INSERT INTO #TmpDBsToProcess
	SELECT	PDB_Name
	FROM	T_Peptide_Database_List
	WHERE PDB_State <> 100
	ORDER BY PDB_Name
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'could not load temporary table with candidate peptide databases'
		goto done
	end

	---------------------------------------------------
	-- Lookup the standard folder paths and filenames
	-- Note that the filenames will be overridden since they
	--  are customized based on the jobs included in the task
	---------------------------------------------------
	--
	exec @myError = GetPeptideProphetFolderPaths
										@clientPerspective,
										@TransferFolderPathBase output,
										'', -- @JobListFileName
										'', -- @ResultsFileName
										@message = @message output

	---------------------------------------------------
	-- Step through the database list and call
	-- RequestPeptideProphetTask in each one (if it exists)
	-- If a Peptide Prophet task is found, then exit the
	-- while loop
	---------------------------------------------------
	While @done = 0 and @myError = 0  
	Begin -- <a>
	
		If Len(@PreferredDBName) > 0
		Begin
			-- Look for @PreferredDBName in #TmpDBsToProcess
			--
			SELECT	TOP 1 @CurrentDB = Database_Name
			FROM	#TmpDBsToProcess 
			WHERE	Database_Name = @PreferredDBName
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--	
			-- Set PreferredDBName to '' so that we don't check for it on the next loop
			Set @PreferredDBName = ''

			If @myRowCount > 0
				-- Delete @CurrentDB from #TmpDBsToProcess
				DELETE FROM #TmpDBsToProcess
				WHERE Database_Name = @PreferredDBName

			-- If @restrictToDbName = 1, then only check the preferred database
			--
			If @restrictToDbName = 1
				Set @done = 1
		End
		Else
		Begin
			-- Get next available entry from #TmpDBsToProcess
			--
			SELECT TOP 1
					@CurrentDB = Database_Name, 
					@UniqueRowIDCurrent = UniqueRowID
			FROM #TmpDBsToProcess 
			WHERE UniqueRowID > @UniqueRowIDCurrent
			ORDER BY UniqueRowID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--		
			if @myRowCount = 0
				set @done = 1
		End

		If @myRowCount > 0
		Begin -- <b>
		
			-- Check if the database actually exists
			SELECT @SPRowCount = Count(*) 
			FROM master..sysdatabases AS SD
			WHERE SD.NAME = @CurrentDB

			If (@SPRowCount > 0)
			Begin -- <c>

				-- Check if the RequestPeptideProphetTask SP exists for @CurrentDB

				Set @S = ''				
				Set @S = @S + ' SELECT @SPRowCount = COUNT(*)'
				Set @S = @S + ' FROM [' + @CurrentDB + ']..sysobjects'
				Set @S = @S + ' WHERE name = ''RequestPeptideProphetTask'''
							
				EXEC sp_executesql @S, N'@SPRowCount int OUTPUT', @SPRowCount OUTPUT

				If (@SPRowCount > 0)
				Begin -- <d>
					
					-- Call RequestPeptideProphetTask in @CurrentDB

					Set @SPToExec = '[' + @CurrentDB + ']..RequestPeptideProphetTask'
					Set @TransferFolderPath = dbo.udfCombinePaths(@TransferFolderPathBase, @CurrentDB + '\')
					Set @JobListFileName = ''
					Set @ResultsFileName = ''
					
					Exec @myError = @SPToExec	@ProcessorName,
												@ClientPerspective,
												@taskID = @TaskID output, 
												@TaskAvailable = @TaskAvailable output,
												@TransferFolderPath = @TransferFolderPath output,
												@JobListFileName = @JobListFileName output,
												@ResultsFileName = @ResultsFileName output,
												@message = @message output

					If @myError <> 0
					Begin
						Set @message = 'Error calling ' + @SPToExec
						Goto Done
					End

					-- If a task was found, and no error occurred, then set @done = 1 so that
					-- the while loop exits
					If @TaskAvailable = 1 And @myError = 0
					Begin
						Set @done = 1
						Set @dbName = @CurrentDB
					End
					Else
					Begin
						Set @dbName = ''
						Set @TaskAvailable = 0
					End

				End -- </d>
			End -- </c>
		End -- </b>	
	End -- </a>

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	Return @myError

GO
