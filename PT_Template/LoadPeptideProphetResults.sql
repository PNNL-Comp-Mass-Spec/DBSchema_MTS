/****** Object:  StoredProcedure [dbo].[LoadPeptideProphetResults] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure LoadPeptideProphetResults
/****************************************************
**
**	Desc: Loads Peptide Prophet Calculation results
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	07/06/2006
**			07/07/2006 mem - Updated to only post a warning if a job has null rows but all of the null rows have charge 6+ or higher
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			04/30/2014 mem - Now posting a warning if null peptide prophet values are found, but less than 5% of the total rows is null
**
*****************************************************/
(
	@TaskID int,													-- This should correspond to an entry in T_Peptide_Prophet_Task; if 0, then it is ignored; if non-zero, then used to verify that each job associated with the task has at least one entry in @ResultsFileName
	@ResultsFileName varchar(255) = 'PepProphetTaskResults.txt',
	@TransferFolderPath varchar(255) = 'D:\Peptide_Prophet_Xfer\',
	@NextProcessStateForJobs int = 60,
	@AutoDetermineNextProcessState tinyint = 1,						-- If non-zero, then uses T_Event_Log to determine the appropriate value for @NextProcessState (if last Process_State before state 90 was 70, then sets to 70, otherwise, sets to @NextProcessState)
	@ProcessStateLoadError int = 98,
	@message varchar(255) = '' OUTPUT,
	@numJobsProcessed int = 0 OUTPUT,								-- The number of jobs processed
	@numJobsIncomplete int = 0 OUTPUT,								-- The number of jobs with 1 or more null Peptide Prophet values after loading
	@numRowsUpdated int = 0 OUTPUT									-- The number of rows updated in T_Score_Discriminant
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	declare @completionCode tinyint
	set @completionCode = 3

	set @numJobsProcessed = 0
	set @numJobsIncomplete = 0
	set @numRowsUpdated = 0
	set @message = ''
	
	declare @result int
	declare @filePath varchar(512)

	declare @MessageType varchar(32)
	
	declare @JobCurrent int
	declare @NextProcessState int
	declare @PreviousTargetState int
	
	declare @continue tinyint
	declare @CheckForMissingJobs tinyint
	declare @IncompleteJob tinyint

	declare @RowCountTotal int
	declare @RowCountNull int
	declare @RowCountNullCharge5OrLess int
	
	-----------------------------------------------
	-- Set up file names and paths
	-----------------------------------------------
	set @filePath = dbo.udfCombinePaths(@TransferFolderPath, @ResultsFileName)

	declare @fileExists tinyint
	declare @LineCountToSkip int	-- This will be set to a positive number if the file contains a header line
	declare @columnCount int
	
	-----------------------------------------------
	-- Verify that input file exists and count the number of columns
	-----------------------------------------------
	-- Set @LineCountToSkip to a negative value to instruct ValidateDelimitedFile to auto-determine whether or not a header row is present
	Set @LineCountToSkip = -1
	Exec @result = ValidateDelimitedFile @filePath, @LineCountToSkip OUTPUT, @fileExists OUTPUT, @columnCount OUTPUT, @message OUTPUT, @ColumnToUseForNumericCheck = 1
	
	if @result <> 0
	Begin
		If Len(@message) = 0
			Set @message = 'Error calling ValidateDelimitedFile for ' + @filePath + ' (Code ' + Convert(varchar(11), @result) + ')'
		
		Set @myError = 50001
	End
	else
	Begin
		If @columnCount = 0
		Begin
			Set @message = 'Peptide Prophet Task Results file is empty'
			set @myError = 50002
		End
		Else
		Begin
			If @columnCount <> 8
			Begin
				Set @message = 'Peptide Prophet Task Results file contains ' + convert(varchar(11), @columnCount) + ' columns (Expecting 8 columns)'
				set @myError = 50003
			End
		End
	End
	
	-----------------------------------------------
	-- Load Peptide Prophet Task Results from file
	-----------------------------------------------
	
	-- don't do any more if errors at this point
	--
	if @myError <> 0 goto done

	-----------------------------------------------
	-- Create a temporary table to hold contents of file
	-----------------------------------------------
	--
	--if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#TmpPeptideProphetResultsImport]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	--  drop table [dbo].[#TmpPeptideProphetResultsImport]
	
	CREATE TABLE #TmpPeptideProphetResultsImport (
		Job int NOT NULL ,
		RowIndex int NOT NULL ,
		Scan int NOT NULL ,
		Scan_Count smallint NOT NULL ,
		Charge smallint NOT NULL ,
		Peptide varchar(850) NOT NULL ,
		FScore real NOT NULL ,
		Probability real NOT NULL
	)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table'
		goto Done
	end

	-- Add an index to #TmpPeptideProphetResultsImport on column Job
	CREATE CLUSTERED INDEX #IX_TmpPeptideProphetResultsImport ON #TmpPeptideProphetResultsImport(Job)
	
	-----------------------------------------------
	-- Create a temporary table to hold jobs associated with @TaskID
	-----------------------------------------------
	--
	CREATE TABLE #TmpJobsInTask (
		Job int NOT NULL,
		Processed tinyint NOT NULL default(0)
	)

	-- Add an index to #TmpJobsInTask on column Job
	CREATE CLUSTERED INDEX #IX_TmpJobsInTask ON #TmpJobsInTask(Job)
	
	-- Populate #TmpJobsInTask with the jobs associated with @TaskID
	If @TaskID <> 0
	Begin
		INSERT INTO #TmpJobsInTask (Job)
		SELECT Job
		FROM T_Peptide_Prophet_Task_Job_Map
		WHERE Task_ID = @TaskID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End
	
	-----------------------------------------------
	-- bulk load contents of results file into temporary table
	-- using bulk insert function
	-----------------------------------------------
	--
	declare @c nvarchar(2048)

	Set @c = 'BULK INSERT #TmpPeptideProphetResultsImport FROM ' + '''' + @filePath + ''' WITH (FIRSTROW = ' + Convert(varchar(9), @LineCountToSkip+1) + ')' 
	exec @result = sp_executesql @c
	--
	if @result <> 0
	begin
		set @message = 'Problem executing bulk insert'
		set @myError = @result
		goto Done
	end

	-----------------------------------------------
	-- Process the data for each job present in #TmpPeptideProphetResultsImport
	-- We could process the data in bulk, but that leads to too many simultaneous row locks
	-----------------------------------------------
	
	Set @JobCurrent = 0
	SELECT @JobCurrent = MIN(Job)-1
	FROM #TmpPeptideProphetResultsImport
	
	Set @CheckForMissingJobs = 0
	Set @continue = 1 
	While @continue = 1
	Begin -- <a>
		If @CheckForMissingJobs = 0
			SELECT TOP 1 @JobCurrent = Job
			FROM #TmpPeptideProphetResultsImport
			WHERE Job > @JobCurrent
			GROUP BY Job
			ORDER BY Job
		Else
			SELECT TOP 1 @JobCurrent = Job
			FROM #TmpJobsInTask
			WHERE Processed = 0 AND
				  Job > @JobCurrent
			ORDER BY Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myError <> 0
			Goto Done
			
		If @myRowCount <> 1
		Begin
			If @CheckForMissingJobs = 0
			Begin
				-----------------------------------------------
				-- No more entries to process in #TmpPeptideProphetResultsImport
				-- Now look for any unprocessed jobs in #TmpJobsInTask
				-- If any exist, post an entry to the log and update 
				--  their state to @ProcessStateLoadError
				-----------------------------------------------
				--
				Set @JobCurrent = 0
				SELECT @JobCurrent = MIN(Job)-1
				FROM #TmpJobsInTask
			
				Set @CheckForMissingJobs = 1
			End
			Else
				Set @continue = 0
		End
		Else
		Begin -- <b>
			If @CheckForMissingJobs = 0
			Begin -- <c1>
				-----------------------------------------------
				-- Always clear the peptide prophet values 
				-- in T_Score_Discriminant before updating them
				-----------------------------------------------
				--
				UPDATE T_Score_Discriminant
				SET Peptide_Prophet_FScore = Null,
					Peptide_Prophet_Probability = Null
				FROM T_Peptides P INNER JOIN
					T_Score_Discriminant SD ON 
					P.Peptide_ID = SD.Peptide_ID
				WHERE P.Job = @JobCurrent AND
					  NOT (	SD.Peptide_Prophet_FScore IS NULL OR 
							SD.Peptide_Prophet_Probability IS NULL)
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				-----------------------------------------------
				-- Update peptide prophet values in 
				-- table from contents of temporary table
				-----------------------------------------------
				--
				UPDATE T_Score_Discriminant
				SET Peptide_Prophet_FScore = LookupQ.FScore, 
					Peptide_Prophet_Probability = LookupQ.Probability
				FROM T_Score_Discriminant SD INNER JOIN
					  (	SELECT P.Peptide_ID, I.FScore, I.Probability 
						FROM #TmpPeptideProphetResultsImport I INNER JOIN
							T_Peptides P ON 
								I.Job = P.Job AND 
								I.Scan = P.Scan_Number AND 
								I.Scan_Count = P.Number_Of_Scans AND 
								I.Charge = P.Charge_State AND
								I.Peptide = P.Peptide
						WHERE I.Job = @JobCurrent
					  ) LookupQ ON SD.Peptide_ID = LookupQ.Peptide_ID
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				set @numRowsUpdated = @numRowsUpdated + @myRowCount
			End -- </c1>
			
			-----------------------------------------------
			-- See if any rows have null Peptide Prophet values for this job
			-- Ignore charge states > 5
			-- Post an error if at least 5% of the rows are null
			-----------------------------------------------
			--
			Set @RowCountTotal = 0
			Set @RowCountNull = 0
			Set @RowCountNullCharge5OrLess = 0
			SELECT	@RowCountTotal = COUNT(*),
					@RowCountNull = SUM(CASE WHEN SD.Peptide_Prophet_FScore IS NULL OR 
												  SD.Peptide_Prophet_Probability IS NULL 
										THEN 1 ELSE 0 END),
					@RowCountNullCharge5OrLess = SUM(CASE WHEN P.Charge_State <= 5 AND (
																SD.Peptide_Prophet_FScore IS NULL OR 
																SD.Peptide_Prophet_Probability IS NULL)
										THEN 1 ELSE 0 END)
			FROM T_Peptides P INNER JOIN
				 T_Score_Discriminant SD ON 
				 P.Peptide_ID = SD.Peptide_ID
			WHERE P.Job = @JobCurrent
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			Declare @FractionNull float = 0
			If @RowCountTotal > 0
				Set @FractionNull = @RowCountNull / Cast(@RowCountTotal As float)
				
			Set @IncompleteJob = 0
			
			If @RowCountNull > 0 Or @CheckForMissingJobs = 1
			Begin

				If @CheckForMissingJobs = 0
					set @message = ''
				Else
					set @message = 'Job ' + Convert(varchar(12), @JobCurrent) + ' not present in Peptide Prophet result file; '

				set @message = @message + 'Job ' + Convert(varchar(12), @JobCurrent) + ' has ' + Convert(varchar(12), @RowCountNull) + ' out of ' + Convert(varchar(12), @RowCountTotal) + ' rows in T_Score_Discriminant with null peptide prophet FScore or Probability values'

				If @RowCountNullCharge5OrLess = 0
				Begin
					set @message = @message + '; however, all have charge state 6+ or higher'
					set @MessageType = 'Warning'
				End
				Else
				Begin
					If @FractionNull > 0.05
					Begin
						set @message = @message + '; furthermore, ' + Convert(varchar(12), @RowCountNullCharge5OrLess) + ' of the rows have charge state 5+ or less'
						set @MessageType = 'Error'
					
						Set @IncompleteJob = 1		
					End
					Else
					Begin
						Declare @PctNull varchar(24) = Convert(varchar(12), Convert(decimal(5,1), @FractionNull * 100))
						set @message = @message + ' (' + @PctNull + '% are null)'
						set @MessageType = 'Warning'
					End
				End

				If @CheckForMissingJobs = 1
				Begin
					-- Always post an error for missing jobs
					Set @MessageType = 'Error'
					Set @IncompleteJob = 1
				End

				execute PostLogEntry @MessageType, @message, 'LoadPeptideProphetResults'

				Set @message = ''
			End
			
			If @IncompleteJob = 1
			Begin
				set @NextProcessState = @ProcessStateLoadError
				set @numJobsIncomplete = @numJobsIncomplete + 1
			End
			Else
			Begin -- <c2>
				Set @NextProcessState = @NextProcessStateForJobs

				If @AutoDetermineNextProcessState <> 0
				Begin -- <d>
					-- Examine T_Event_Log to see if @JobCurrent had Process_State 70
					--  prior to changing to Process_State 90
					-- If it did, use 70 for @NextProcessState rather than 

					Set @PreviousTargetState = 0
					SELECT @PreviousTargetState = EL.Prev_Target_State
					FROM T_Event_Log EL INNER JOIN
							(	SELECT MAX(EL.Event_ID) AS Event_ID_Max
								FROM T_Event_Log EL
								WHERE EL.Target_ID = @JobCurrent AND
									  EL.Target_Type = 1 AND 
									  EL.Target_State = 90 AND
									  EL.Prev_Target_State < 90
							) LookupQ ON 
						EL.Event_ID = LookupQ.Event_ID_Max

					If @PreviousTargetState = 70
						Set @NextProcessState = 70
				End -- </d>
			End -- </c2>
			
			Exec SetProcessState @JobCurrent, @NextProcessState

			-- Mark this job as processed
			UPDATE #TmpJobsInTask
			SET Processed = 1
			WHERE Job = @JobCurrent
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			Set @numJobsProcessed = @numJobsProcessed + 1
		End -- </b>
	End -- </a>
	
	-----------------------------------------------
	-- log entry
	-----------------------------------------------

	Set @message = 'Imported Peptide Prophet task results: ' + convert(varchar(12), @numRowsUpdated) + ' rows updated for ' + Convert(varchar(9), @numJobsProcessed) + ' job'
	If @numJobsProcessed <> 1
		Set @message = @message + 's'

	If @numJobsIncomplete > 0
	Begin
		Set @message = @message + '; task had ' + Convert(varchar(9), @numJobsIncomplete) + ' incomplete job'
		If @numJobsIncomplete <> 1
			Set @message = @message + 's'
	End

	-----------------------------------------------
	-- Exit
	-----------------------------------------------
Done:	
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[LoadPeptideProphetResults] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[LoadPeptideProphetResults] TO [MTS_DB_Lite] AS [dbo]
GO
