/****** Object:  StoredProcedure [dbo].[VerifySequenceInfo] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure [dbo].[VerifySequenceInfo]
/****************************************************
**
**	Desc:
**		Refreshes local copy of sequences table
**      from the master sequence database and
**      verifies that all the necessary information
**      is available (for now, just monoisotopic mass)
**
**		Works on all the peptides
**      for the all the analyses with
**		Process_State = @ProcessStateMatch
**
**	Return values: 0: end of line not yet encountered
**
**	Parameters:
**
**	Auth:	grk
**	Date:	07/30/2004
**			08/07/2004 mem - Updated Insert Into T_Sequence query plus various other updates
**			09/09/2004 mem - Switched to a consolidated query to simultaneously check all jobs with state @ProcessStateMatch
**			02/23/2005 mem - Now checking for jobs in State @ProcessStateMatch that have Last_Affected over 96 hours old
**			02/23/2005 mem - Switched Master_Sequences location from PrismDev to Albert
**			11/28/2005 mem - Now updating masses in T_Sequences via an alternate query if jobs are present in state 30
**			02/18/2006 mem - Now also looking for jobs with state @ProcessStateMatch but present in T_Joined_Job_Details; setting their state to 39 rather than @NextProcessState
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**			03/18/2006 mem - Changed @NextProcessState from 40 to 33
**						   - No longer checking for jobs in T_Joined_Job_Details; moved that logic to MasterUpdateProcessBackground
**			05/03/2006 mem - Switched Master_Sequences location from Albert to Daffy
**			11/21/2006 mem - Switched Master_Sequences location from Daffy to ProteinSeqs
**			07/23/2008 mem - Switched Master_Sequences location to Porky
**			11/05/2009 mem - Changed default value for @NextProcessState to 31
**			02/25/2010 mem - Switched Master_Sequences location to ProteinSeqs2
**			11/11/2010 mem - Now calling CalculateMonoisotopicMass when SkipPeptidesFromReversedProteins is 0 in T_Process_Step_Control
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			12/04/2019 mem - Switched Master_Sequences location to Pogo
**
*****************************************************/
(
	@ProcessStateMatch int = 30,
	@NextProcessState int = 31,
	@numJobsToProcess int = 50000,
	@numJobsProcessed int = 0 OUTPUT,
	@numJobsAdvancedToNextState int = 0 OUTPUT
)
AS
	Set NoCount On

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	set @numJobsProcessed = 0
	set @numJobsAdvancedToNextState = 0

	declare @JobMatchCount int
	declare @numAgedJobs int
	declare @maxAgeHours int
	set @numAgedJobs = 0
	set @maxAgeHours = 96

	declare @UpdateEnabled tinyint
	declare @message varchar(255)
	set @message = ''

	declare @SkipPeptidesFromReversedProteins tinyint

	----------------------------------------------
	-- Determine the number of jobs in state @ProcessStateMatch
	----------------------------------------------
	Set @JobMatchCount = 0
	SELECT @JobMatchCount = Count(*)
	FROM T_Analysis_Description
	WHERE Process_State = @ProcessStateMatch

	----------------------------------------------
	-- Try to update monoisotopic mass of any entries
	-- in local sequence table with a null value
	----------------------------------------------
	If @JobMatchCount > 0
	Begin
		-- This query runs faster when jobs are present in state @ProcessStateMatch
		-- First, post an entry to the log that this query is starting

		set @message = 'Updating mass information for sequences; ' + convert(varchar(11), @JobMatchCount) + ' jobs in state ' + Convert(varchar(9), @ProcessStateMatch)
		exec PostLogEntry 'Normal', @message, 'VerifySequenceInfo'

		UPDATE T_Sequence
		SET Monoisotopic_Mass = M.Monoisotopic_Mass
		FROM T_Sequence S INNER JOIN
				(	SELECT DISTINCT P.Seq_ID
					FROM T_Peptides P INNER JOIN
						 T_Analysis_Description TAD ON
						 P.Job = TAD.Job
					WHERE TAD.Process_State = @ProcessStateMatch
				) AS SequenceQ ON
				SequenceQ.Seq_ID = S.Seq_ID INNER JOIN
				(	SELECT Monoisotopic_Mass, Seq_ID
					FROM Pogo.Master_Sequences.dbo.T_Sequence
				) M ON S.Seq_ID = M.Seq_ID
		WHERE S.Monoisotopic_Mass IS NULL AND
			  NOT (M.Monoisotopic_Mass IS NULL)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End
	Else
	Begin
		-- This query runs faster when no jobs are present in state @ProcessStateMatch
		UPDATE T_Sequence
		SET Monoisotopic_Mass = M.Monoisotopic_Mass
		FROM T_Sequence INNER JOIN
		(
			SELECT Monoisotopic_Mass, Seq_ID
			FROM Pogo.Master_Sequences.dbo.T_Sequence
		) AS M ON T_Sequence.Seq_ID = M.Seq_ID
		WHERE T_Sequence.Monoisotopic_Mass IS NULL AND
			NOT M.Monoisotopic_Mass IS NULL
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End
	--
	if @myError <> 0
	begin
		set @message = 'Error while updating monoisotopic masses in T_Sequences'
		set @myError = 102
		goto done
	end
	else
	begin
		if @myRowCount > 0
		begin
			set @message = 'Updated mass information for sequences: ' + convert(varchar(11), @myRowCount) + ' updated'
			exec PostLogEntry 'Normal', @message, 'VerifySequenceInfo'
		end
	end

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'VerifySequenceInfo', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


	--------------------------------------------------------------
	-- Lookup the value of SkipPeptidesFromReversedProteins in T_Process_Step_Control
	-- Assume skipping is enabled if the value is not present
	--------------------------------------------------------------
	--
	SELECT @SkipPeptidesFromReversedProteins = Enabled
	FROM T_Process_Step_Control
	WHERE Processing_Step_Name = 'SkipPeptidesFromReversedProteins'
	--
	SELECT @myRowcount = @@rowcount, @myError = @@error

	Set @SkipPeptidesFromReversedProteins = IsNull(@SkipPeptidesFromReversedProteins, 1)

	If @SkipPeptidesFromReversedProteins = 0
	Begin
		-- Calculate monoisotopic mass values for any entries in T_Sequence with null mass values
		exec CalculateMonoisotopicMass @message=@message output, @RecomputeAll=0, @VerifyUpdateEnabled=1
	End


	----------------------------------------------
	-- Verify non-null monoisotopic mass for all peptides
	--  for jobs with Process_State = @ProcessStatematch
	-- Instead of processing jobs one at a time, analyze all
	--  jobs in state @ProcessStateMatch simultaneously,
	--  storing results in a temporary table
	----------------------------------------------

	CREATE TABLE #MassStatsByJob (
		Job int,
		NullMassCount int
	)

	INSERT INTO #MassStatsByJob (Job, NullMassCount)
	SELECT	P.Job,
			SUM(CASE WHEN S.Monoisotopic_Mass IS NULL
				THEN 1
				ELSE 0
				END) AS NullMassCount
	FROM T_Peptides P INNER JOIN
		 T_Sequence S ON P.Seq_ID = S.Seq_ID INNER JOIN
	  T_Analysis_Description TAD ON P.Job = TAD.Job
	WHERE TAD.Process_State = @ProcessStateMatch
	GROUP BY P.Job
	--
	SELECT @myError = @@error, @numJobsProcessed = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error while examining completeness of jobs in state ' + convert(varchar(9), @ProcessStateMatch)
		set @myError = 103
		goto done
	end

	----------------------------------------------
	-- Advance jobs with a NullMassCount of 0 to the next state
	----------------------------------------------
	UPDATE T_Analysis_Description
	SET Process_State = @NextProcessState, Last_Affected = GetDate()
	FROM T_Analysis_Description TAD INNER JOIN
		 #MassStatsByJob ON TAD.Job = #MassStatsByJob.Job
	WHERE #MassStatsByJob.NullMassCount = 0
	--
	SELECT @myError = @@error, @numJobsAdvancedToNextState = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error while updating Process_State for appropriate jobs'
		set @myError = 104
		goto done
	end


	if @numJobsAdvancedToNextState < @numJobsProcessed
	Begin
		SELECT @numAgedJobs = COUNT(*)
		FROM T_Analysis_Description
		WHERE Process_State = @ProcessStateMatch AND
			  DateDiff(hour, Last_Affected, GetDate()) >= @maxAgeHours

		If @numAgedJobs > 0
		Begin
			Set @message = 'Warning: Found ' + convert(varchar(9), @numAgedJobs) + ' jobs that have been in state ' + convert(varchar(9), @ProcessStateMatch) + ' for over ' + convert(varchar(9), @maxAgeHours) + ' hours'
			execute PostLogEntry 'Error', @message, 'VerifySequenceInfo', 24
			Set @message = ''
		End
	End

	if @numJobsProcessed = 0
		set @message = 'no analyses were available'

	-----------------------------------------------
	-- exit the stored procedure
	-----------------------------------------------
	--
Done:

	-- Post a log entry if an error exists
	if @myError <> 0
		execute PostLogEntry 'Error', @message, 'VerifySequenceInfo'

	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[VerifySequenceInfo] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[VerifySequenceInfo] TO [MTS_DB_Lite] AS [dbo]
GO
