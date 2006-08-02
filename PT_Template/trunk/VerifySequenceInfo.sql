SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[VerifySequenceInfo]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[VerifySequenceInfo]
GO


CREATE PROCEDURE dbo.VerifySequenceInfo
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
**		Auth: grk
**		Date: 7/30/2004
**
**		Updated: 08/07/2004 mem - Updated Insert Into T_Sequence query plus various other updates
**				 09/09/2004 mem - Switched to a consolidated query to simultaneously check all jobs with state @ProcessStateMatch
**				 02/23/2005 mem - Now checking for jobs in State @ProcessStateMatch that have Last_Affected over 96 hours old
**				 02/23/2005 mem - Switched Master_Sequences location from PrismDev to Albert
**				 11/28/2005 mem - Now updating masses in T_Sequences via an alternate query if jobs are present in state 30
**    
*****************************************************/
	@ProcessStateMatch int = 30,
	@NextProcessState int = 40,
	@numJobsToProcess int = 50000,
	@numJobsProcessed int = 0 OUTPUT,
	@numJobsAdvancedToNextState int = 0 OUTPUT
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
		
	declare @message varchar(255)
	set @message = ''
	
	-- Determine the number of jobs in state @ProcessStateMatch
	
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
						 P.Analysis_ID = TAD.Job
					WHERE TAD.Process_State = @ProcessStateMatch
				) AS SequenceQ ON 
				SequenceQ.Seq_ID = S.Seq_ID INNER JOIN
				(	SELECT Monoisotopic_Mass, Seq_ID
					FROM Albert.Master_Sequences.dbo.T_Sequence
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
			FROM Albert.Master_Sequences.dbo.T_Sequence
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
	SELECT	P.Analysis_ID AS Job, 
			SUM(CASE WHEN S.Monoisotopic_Mass IS NULL 
				THEN 1 
				ELSE 0 
				END) AS NullMassCount
	FROM T_Peptides P INNER JOIN 
		 T_Sequence S ON P.Seq_ID = S.Seq_ID INNER JOIN
	  T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job
	WHERE TAD.Process_State = @ProcessStateMatch
	GROUP BY P.Analysis_ID
	--
	SELECT @myError = @@error, @numJobsProcessed = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Error while examining completeness of jobs in state ' + convert(varchar(9), @ProcessStateMatch)
		set @myError = 103
		goto done
	end
	
	-- Advance jobs with a NullMassCount of 0 to the next state
	UPDATE T_Analysis_Description
	SET Process_State = @NextProcessState, Last_Affected = GetDate()
	FROM T_Analysis_Description INNER JOIN #MassStatsByJob ON
		 T_Analysis_Description.Job = #MassStatsByJob.Job
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

