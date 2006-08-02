SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[RequestGANETUpdateTaskMaster]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[RequestGANETUpdateTaskMaster]
GO

CREATE PROCEDURE dbo.RequestGANETUpdateTaskMaster
/****************************************************
**
**	Desc: 
**		For each database listed in T_MT_Database_List
**      Calls the RequestGANETUpdateTask SP
**      If @TaskAvailable = 1, then exits the loop and
**      exits this SP, returning the parameters returned
**      by the RequestGANETUpdateTask SP.  If
**      @TaskAvailable = 0, then continues calling
**      RequestGANETUpdateTask in each database until 
**      all have been called.
**
**		If @dbName is provided, will check that DB first
**		If @restrictToDbName = 1, then only checks @dbName
**
**		Auth: grk
**		Date: 8/26/2003
**		Updated: 02/19/2004 mem - Added check to confirm that each database actually exists
**				 04/09/2004 mem - Removed @maxIterations and @maxHours parameters
**				 07/05/2004 mem - Extended SP to call RequestGANETUpdateTask in the peptide DB's, in addition to the MTDB's
**				 07/30/2004 mem - Added @unmodifiedPeptidesOnly, @noCleavageRuleFilters, and @skipRegression parameters
**				 01/28/2005 mem - Updated bug involving @outFile, @inFile, and @predFile population for MTDB's
**				 04/08/2005 mem - Updated call to GetGANETFolderPaths
**				 05/28/2005 mem - Now passing @inFilePath to RequestGANETUpdateTask in Peptide DBs
**			     11/23/2005 mem - Added brackets around @CurrentDB as needed to allow for DBs with dashes in the name
**
*****************************************************/
	@processorName varchar(128),
	@clientPerspective tinyint = 1,					-- 0 means running SP from local server; 1 means running SP from client
	@restrictToDbName tinyint = 0,					-- If 1, will only check the DB named @dbName
	@taskID int = 0 output,							-- Ganet Update Task if a Mass Tag DB, a Job if a Peptide DB
	@dbName varchar(128) = '' output,				-- if provided, will preferentially query that database first
	@outFile varchar(256) = '' output,				-- Source file name
	@outFilePath varchar(256) = '' output,			-- Source file folder path
	@inFile varchar(256) = '' output,				-- Results file name
	@inFilePath varchar(256) = '' output,			-- Results file folder path
	@predFile varchar(256) = '' output,				-- Predict NETs results file name
	@unmodifiedPeptidesOnly tinyint = 0 output,		-- 1 if we should only consider unmodified peptides
	@noCleavageRuleFilters tinyint = 0 output,		-- 1 if we should use the looser filters that do not consider cleavage rules
	@skipRegression tinyint = 0 output,				-- 1 if we should skip the regression and only make the plots
	@taskAvailable tinyint = 0 output,				-- 1 if a task is available; otherwise 0
	@message varchar(512) = '' output
As
	set nocount on

	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	declare @done int
	set @done = 0

	declare @ActivityRowCount int
	set @ActivityRowCount = 0

	declare @SPRowCount int
	set @SPRowCount = 0
	
	-- Note: @S needs to be unicode (nvarchar) for compatibility with sp_executesql
	declare @S nvarchar(1024),
			@CurrentDB varchar(255),
			@SPToExec varchar(255),
			@PreferredDBName varchar(255),
			@outFileFolderPathBase varchar(255),
			@inFileFolderPathBase varchar(255),
			@IsPeptideDB tinyint

	set @S = ''
	set @CurrentDB = ''
	set @SPToExec = ''
	set @PreferredDBName = IsNull(@dbName, '')
	set @message = ''
		
	---------------------------------------------------
	-- clear the output arguments
	---------------------------------------------------
	set @taskID = 0
	set @dbName = ''
	set @outFile = ''
	set @outFilePath = ''
	set @outFileFolderPathBase = ''
	set @inFile = ''
	set @inFileFolderPathBase = ''
	set @inFilePath = ''
	set @predFile = ''
	set @unmodifiedPeptidesOnly = 0		-- Future: Obtain this from the peptide or mass tag database with the GANET update task
	set @noCleavageRuleFilters = 0		-- Future: Obtain this from the peptide or mass tag database
	set @skipRegression = 0				-- Future: Obtain this from the peptide or mass tag database
	set @taskAvailable = 0

	---------------------------------------------------
	-- temporary table to hold list of databases to process
	---------------------------------------------------
	CREATE TABLE #XDBNames (
		Database_Name varchar(128),
		Processed tinyint,
		IsPeptideDB tinyint
	) 

	---------------------------------------------------
	-- populate temporary table with list of mass tag
	-- databases that are not deleted
	---------------------------------------------------
	INSERT INTO #XDBNames
	SELECT	MTL_Name, 0 As Processed, 0 As IsPeptideDB
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

	---------------------------------------------------
	-- add the peptide databases that are not deleted
	---------------------------------------------------
	INSERT INTO #XDBNames
	SELECT	PDB_Name, 0 As Processed, 1 As IsPeptideDB
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
	-- For Peptide DB's, the filenames will be overridden
	---------------------------------------------------
	--
	Declare @outFileNameDefault varchar(256),
			@inFileNameDefault varchar(256),
			@predFileNameDefault varchar(256)
	
	set @outFileNameDefault = ''
	set @inFileNameDefault = ''
	set @predFileNameDefault = ''

	exec @myError = GetGANETFolderPaths
										@clientPerspective,
										@outFileNameDefault output,
										@outFileFolderPathBase  output,
										@inFileNameDefault  output,
										@inFileFolderPathBase  output,
										@predFileNameDefault  output,
										@message  output

	---------------------------------------------------
	-- step through the database list and call
	-- RequestGANETUpdateTask in each one (if it exists)
	-- If a GANET regression task is found, then exit the
	-- while loop
	---------------------------------------------------
	WHILE @done = 0 and @myError = 0  
	BEGIN --<a>
	
		If Len(@PreferredDBName) > 0
			begin
				-- Look for @PreferredDBName in XDBNames
				--
				SELECT	TOP 1 @CurrentDB = Database_Name, @IsPeptideDB = IsPeptideDB
				FROM	#XDBNames 
				WHERE	Processed = 0 AND Database_Name = @PreferredDBName
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--	
				-- Set PreferredDBName to '' so that we don't check for it on the next loop
				Set @PreferredDBName = ''
			end
		else
			begin
				-- Get next available entry from XDBNames
				--
				SELECT	TOP 1 @CurrentDB = Database_Name, @IsPeptideDB = IsPeptideDB
				FROM	#XDBNames 
				WHERE	Processed = 0
				ORDER BY Database_Name
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--		
				if @myRowCount = 0
					set @done = 1
			end

		If @myRowCount > 0
		begin --<b>
		
			-- update Process_State entry for given DB to 1
			--
			UPDATE	#XDBNames
			SET		Processed = 1
			WHERE	(Database_Name = @CurrentDB)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0 
			begin
				set @message = 'Could not update the database list temp table'
				set @myError = 51
				goto Done
			end

			-- Check if the database actually exists
			SELECT @SPRowCount = Count(*) 
			FROM master..sysdatabases AS SD
			WHERE SD.NAME = @CurrentDB

			If (@SPRowCount > 0)
			Begin --<c>

				-- Check if the RequestGANETUpdateTask SP exists for @CurrentDB

				Set @S = ''				
				Set @S = @S + ' SELECT @SPRowCount = COUNT(*)'
				Set @S = @S + ' FROM [' + @CurrentDB + ']..sysobjects'
				Set @S = @S + ' WHERE name = ''RequestGANETUpdateTask'''
							
				EXEC sp_executesql @S, N'@SPRowCount int OUTPUT', @SPRowCount OUTPUT

				If (@SPRowCount > 0)
				Begin --<d>
					
					-- Call RequestGANETUpdateTask in @CurrentDB
					-- Peptide DB's require extra parameters

					Set @SPToExec = '[' + @CurrentDB + ']..RequestGANETUpdateTask'
					Set @outFilePath = @outFileFolderPathBase + @CurrentDB + '\'
					Set @inFilePath = @inFileFolderPathBase + @CurrentDB + '\'
					
					If @IsPeptideDB = 1
					  Begin
						-- Peptide DB
						-- Note that @outFile, @inFile, and @predFile will get overridden with customized names
						Exec @myError = @SPToExec	
													@ProcessorName,
													@outFilePath,				-- Note that this is a folder path
													@taskID output, 
													@TaskAvailable = @TaskAvailable output,
													@outFileName = @outFile output,
													@inFileName = @inFile output,
													@predFileName = @predFile output,
													@message = @message output
					  End
					Else
					  Begin
						-- Mass Tag DB
						Exec @myError = @SPToExec	
													@ProcessorName,
													@taskID = @taskID output, 
													@TaskAvailable = @TaskAvailable output,
													@message = @message output
													
						If @TaskAvailable = 1
						Begin
							Set @outfile = @outFileNameDefault
							Set @inFile = @inFileNameDefault
							Set @predFile = @predFileNameDefault
						End
					  End
					

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

				End --<d>
										
			End --<c>

		end --<b>	
			
		-- If @restrictToDbName = 1, then only check the preferred database
		--
		If @restrictToDbName = 1
			Set @done = 1
				   
	END --<a>


	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:

	Return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[RequestGANETUpdateTaskMaster]  TO [DMS_SP_User]
GO

