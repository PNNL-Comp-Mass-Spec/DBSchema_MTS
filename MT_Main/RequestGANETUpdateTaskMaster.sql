/****** Object:  StoredProcedure [dbo].[RequestGANETUpdateTaskMaster] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.RequestGANETUpdateTaskMaster
/****************************************************
**
**	Desc:	For each database listed in T_MT_Database_List, calls the RequestGANETUpdateTask SP
**			If @TaskAvailable = 1, then exits the loop and exits this SP, returning 
**			 the parameters returned by the RequestGANETUpdateTask SP.  If @TaskAvailable = 0, 
**			 then continues calling RequestGANETUpdateTask in each database until all have been called.
**
**			If @dbName is provided, will check that DB first
**			If @restrictToDbName = 1, then only checks @dbName
**
**	Auth:	grk
**	Date:	08/26/2003
**			02/19/2004 mem - Added check to confirm that each database actually exists
**			04/09/2004 mem - Removed @maxIterations and @maxHours parameters
**			07/05/2004 mem - Extended SP to call RequestGANETUpdateTask in the peptide DB's, in addition to the MTDB's
**			07/30/2004 mem - Added @UnmodifiedPeptidesOnly, @NoCleavageRuleFilters, and @skipRegression parameters
**			01/28/2005 mem - Updated bug involving @SourceFileName, @ResultsFileName, and @PredNETsFileName population for MTDB's
**			04/08/2005 mem - Updated call to GetGANETFolderPaths
**			05/28/2005 mem - Now passing @ResultsFolderPathBase to RequestGANETUpdateTask in Peptide DBs
**			11/23/2005 mem - Added brackets around @CurrentDB as needed to allow for DBs with dashes in the name
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**			07/05/2006 mem - Now using dbo.udfCombinePaths() to combine paths
**			03/13/2010 mem - Removed parameters @clientPerspective and @skipRegression
**			03/13/2010 mem - Reordered the parameters and added several new parameters (@ObsNETsFile, @UnmodifiedPeptidesOnly, @NoCleavageRuleFilters, and @RegressionOrder)
**			03/19/2010 mem - Added parameter @ParamFileName
**			04/06/2010 mem - Changed default value for @ParamFileName (now using LCMSWarp with 10 sections)
**			04/20/2010 mem - Changed default value for @ParamFileName (now using LCMSWarp with 30 sections)
**			01/18/2012 mem - Now calling VerifyUpdateEnabled separately for PT and MT databases
**
*****************************************************/
(
	@processorName varchar(128),
	@restrictToDbName tinyint = 0,					-- If 1, will only check the DB named @dbName
	@taskID int = 0 output,							-- Ganet Update Task if a Mass Tag DB, a Job if a Peptide DB
	@dbName varchar(128) = '' output,				-- if provided, will preferentially query that database first

	@SourceFolderPath varchar(256) = '' output,		-- Source file folder path (determined using MT_Main.dbo.T_Folder_Paths) e.g. \\porky\GA_Net_Xfer\Out\PT_Shewanella_ProdTest_A123\
	@SourceFileName varchar(256) = '' output,		-- Source file name

	@ResultsFolderPath varchar(256) = '' output,	-- Results folder path (determined using MT_Main.dbo.T_Folder_Paths) e.g. \\porky\GA_Net_Xfer\In\PT_Shewanella_ProdTest_A123\
	@ResultsFileName varchar(256) = '' output,		-- Results file name
	@PredNETsFileName varchar(256) = '' output,		-- Predict NETs results file name
	@ObsNETsFileName varchar(256) = '' output,		-- Observed NETs results file name

	@ParamFileName varchar(256) = '' output,		-- If this is defined, then settings in the parameter file will superseded the following 5 parameters
	
	@UnmodifiedPeptidesOnly tinyint = 0 output,		-- 1 if we should only consider unmodified peptides
	@NoCleavageRuleFilters tinyint = 0 output,		-- 1 if we should use the looser filters that do not consider cleavage rules
	@RegressionOrder tinyint = 3 output,			-- 1 for linear regression, >=2 for non-linear regression

	@taskAvailable tinyint = 0 output,				-- 1 if a task is available; otherwise 0,	
	@message varchar(512) = '' output,
	@ShowDebugInfo tinyint = 0
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
	declare @S nvarchar(2048),
			@CurrentDB varchar(255),
			@UniqueRowIDCurrent int,
			@SPToExec varchar(255),
			@PreferredDBName varchar(255),
			@SourceFolderPathBase varchar(255),
			@ResultsFolderPathBase varchar(255),
			@IsPeptideDB tinyint

	set @S = ''
	set @CurrentDB = ''
	set @UniqueRowIDCurrent = 0
	set @SPToExec = ''
	set @PreferredDBName = IsNull(@dbName, '')
	set @message = ''
	Set @ShowDebugInfo = IsNull(@ShowDebugInfo, 0)
		
	
	---------------------------------------------------
	-- Clear the output arguments
	---------------------------------------------------
	set @taskID = 0
	set @dbName = ''
	
	set @SourceFolderPath = ''
	set @SourceFileName = ''
	set @SourceFolderPathBase = ''
	
	set @ResultsFolderPath = ''
	set @ResultsFileName = ''
	set @ResultsFolderPathBase = ''
	set @PredNETsFileName = ''	
	set @ObsNETsFileName = ''
	
	Set @ParamFileName = ''
	
	set @UnmodifiedPeptidesOnly = 0		-- 1 if we should only consider unmodified peptides and peptides with alkylated cysteine
	set @NoCleavageRuleFilters = 0		-- 1 if we should use the looser filters that do not consider cleavage rules
	Set @RegressionOrder = 3			-- 1 for first order, 3 for non-linear

	set @taskAvailable = 0


	---------------------------------------------------
	-- Create a temporary table to hold list of databases to process
	---------------------------------------------------
	CREATE TABLE #TmpDBsToProcess (
		UniqueRowID int identity(1,1),
		Database_Name varchar(128),
		IsPeptideDB tinyint
	) 

	-- Add an index to #TmpDBsToProcess on column UniqueRowID
	CREATE CLUSTERED INDEX #IX_TmpDBsToProcess ON #TmpDBsToProcess(UniqueRowID)

	-- Validate that Peptide DB updating is enabled; skip Peptide DBs if not enabled
	exec VerifyUpdateEnabled 'Peptide_DB_Update', 'RequestGANETUpdateTaskMaster', @AllowPausing = 0, @PostLogEntryIfDisabled = 0, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled > 0
	Begin
		---------------------------------------------------
		-- Add the peptide databases that are not deleted
		---------------------------------------------------
		INSERT INTO #TmpDBsToProcess (Database_Name, IsPeptideDB)
		SELECT	PDB_Name, 1 As IsPeptideDB
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
	End

	-- Validate that AMT tag DB updating is enabled; skip MT DBs if not enabled
	exec VerifyUpdateEnabled 'PMT_Tag_DB_Update', 'RequestGANETUpdateTaskMaster', @AllowPausing = 0, @PostLogEntryIfDisabled = 0, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled > 0
	Begin
		---------------------------------------------------
		-- Populate the temporary table with the list of 
		-- mass tag databases that are not deleted
		---------------------------------------------------
		INSERT INTO #TmpDBsToProcess (Database_Name, IsPeptideDB)
		SELECT	MTL_Name, 0 As IsPeptideDB
		FROM	T_MT_Database_List
		WHERE MTL_State <> 100
		ORDER BY MTL_Name
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'could not load temporary table with candidate mass tag databases'
			goto done
		end
	End
	
	If Not Exists (Select * From #TmpDBsToProcess)
	Begin
		-- Nothing to do
		Goto done
	End
	
	---------------------------------------------------
	-- Lookup the standard folder paths and filenames
	-- For Peptide DB's, the filenames will be overridden
	---------------------------------------------------
	--
	Declare @SourceFileNameDefault varchar(256),
			@ResultsFileNameDefault varchar(256),
			@PredNETsFileNameDefault varchar(256),
			@ObsNETsFileNameDefault varchar(256)
	
	set @SourceFileNameDefault = ''
	set @ResultsFileNameDefault = ''
	set @PredNETsFileNameDefault = ''
	set @ObsNETsFileNameDefault = ''
	
	If @ShowDebugInfo <> 0
		Print 'Call GetGANETFolderPaths'
		
	exec @myError = GetGANETFolderPaths
										@clientPerspective = 1,
										@SourceFileName=@SourceFileNameDefault output,
										@SourceFolderPath=@SourceFolderPathBase  output,
										@ResultsFileName=@ResultsFileNameDefault  output,
										@ResultsFolderPath=@ResultsFolderPathBase  output,
										@PredNETsFileName=@PredNETsFileNameDefault  output,
										@ObsNETsFileName=@ObsNETsFileNameDefault output,
										@message=@message  output

	If @ShowDebugInfo <> 0
		SELECT @SourceFileNameDefault AS SourceFileNameDefault,
		       @SourceFolderPathBase AS SourceFolderPathBase,
		       @ResultsFileNameDefault AS ResultsFileNameDefault,
		       @ResultsFolderPathBase AS ResultsFolderPathBase,
		       @PredNETsFileNameDefault AS PredNETsFileNameDefault,
		       @ObsNETsFileNameDefault AS ObsNETsFileNameDefault
		
	---------------------------------------------------
	-- Step through the database list and call
	-- RequestGANETUpdateTask in each one (if it exists)
	-- If a GANET regression task is found, then exit the
	-- while loop
	---------------------------------------------------
	While @done = 0 and @myError = 0  
	Begin -- <a>
	
		If Len(@PreferredDBName) > 0
		Begin
			-- Look for @PreferredDBName in #TmpDBsToProcess
			--
			SELECT	TOP 1 @CurrentDB = Database_Name, @IsPeptideDB = IsPeptideDB
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
					@IsPeptideDB = IsPeptideDB,
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
			FROM sys.databases
			WHERE [NAME] = @CurrentDB

			If (@SPRowCount = 0)
			Begin
				If @ShowDebugInfo <> 0
					Print 'DB not found: ' + @CurrentDB
			End
			Else
			Begin -- <c>

				-- Check if the RequestGANETUpdateTask SP exists for @CurrentDB

				Set @S = ''				
				Set @S = @S + ' SELECT @SPRowCount = COUNT(*)'
				Set @S = @S + ' FROM [' + @CurrentDB + ']..sysobjects'
				Set @S = @S + ' WHERE name = ''RequestGANETUpdateTask'''
							
				EXEC sp_executesql @S, N'@SPRowCount int OUTPUT', @SPRowCount OUTPUT

				If (@SPRowCount = 0)
				Begin
					If @ShowDebugInfo <> 0
						Print 'Stored procedure RequestGANETUpdateTask not found in DB ' + @CurrentDB
				End
				Else
				Begin -- <d>
					
					-- Call RequestGANETUpdateTask in @CurrentDB
					-- Peptide DB's require extra parameters

					Set @SPToExec = '[' + @CurrentDB + ']..RequestGANETUpdateTask'
					Set @SourceFolderPath = dbo.udfCombinePaths(@SourceFolderPathBase, @CurrentDB + '\')
					Set @ResultsFolderPath = dbo.udfCombinePaths (@ResultsFolderPathBase, @CurrentDB + '\')
					
					If @ShowDebugInfo <> 0
						Print 'Call ' + @SPToExec

					If @IsPeptideDB = 1
					Begin
						-- Peptide DB
						-- Note that @SourceFileName, @ResultsFileName, @PredNETsFileName, and @ObsNETsFileName will get overridden with customized names
						-- We set @SourceFolderPath and @ResultsFolderPath to '' when calling becuase we want the procedure 
						--  to determine the local paths to the folders (e.g. I:\GA_Net_Xfer\Out\PT_Shewanella_ProdTest_A123\)
						
						Exec @myError = @SPToExec	
													@ProcessorName,
													@taskID output, 
													@TaskAvailable = @TaskAvailable output,
													
													@SourceFolderPath = '',
													@SourceFileName = @SourceFileName output,
													
													@ResultsFolderPath = '',
													@ResultsFileName = @ResultsFileName output,
													@PredNETsFileName = @PredNETsFileName output,
													@ObsNETsFileName = @ObsNETsFileName output,
													
													@UnmodifiedPeptidesOnly = @UnmodifiedPeptidesOnly output,
													@NoCleavageRuleFilters = @NoCleavageRuleFilters output,
													@RegressionOrder = @RegressionOrder output,
													@ParamFileName = @ParamFileName output,
													
													@message = @message output
					
						If IsNull(@ParamFileName, '') = ''
							Set @ParamFileName = 'LCMSWarp_30Sections_Min20pct_Min20Peptides_SaveGlobalPlots_SaveFilteredJobPlots_2010-04-20.xml'

					End
					Else
					Begin
						-- Mass Tag DB
						Exec @myError = @SPToExec	
													@ProcessorName,
													@taskID = @taskID output, 
													@TaskAvailable = @TaskAvailable output,
													@ParamFileName = @ParamFileName output,
													@message = @message output
													
						If @TaskAvailable = 1
						Begin
							Set @SourceFileName = @SourceFileNameDefault
							Set @ResultsFileName = @ResultsFileNameDefault
							Set @PredNETsFileName = @PredNETsFileNameDefault
							Set @ObsNETsFileName = @ObsNETsFileNameDefault

							If IsNull(@ParamFileName, '') = ''
								Set @ParamFileName = 'LCMSWarp_30Sections_Min20pct_Min20Peptides_SaveGlobalPlots_SaveFilteredJobPlots_2010-04-20.xml'
						End
					End

					If @myError <> 0
					Begin
						Set @message = 'Error calling ' + @SPToExec
						If @ShowDebugInfo <> 0
							Print @message
						Goto Done
					End

					If @ShowDebugInfo <> 0
						Print 'Results for ' + @CurrentDB + ': @TaskAvailable=' + Convert(varchar(12), @TaskAvailable) + ', @taskID=' + Convert(varchar(12), IsNull(@taskID, 0))

						
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
GRANT EXECUTE ON [dbo].[RequestGANETUpdateTaskMaster] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RequestGANETUpdateTaskMaster] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RequestGANETUpdateTaskMaster] TO [MTS_DB_Lite] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[RequestGANETUpdateTaskMaster] TO [pnl\MTSProc] AS [dbo]
GO
