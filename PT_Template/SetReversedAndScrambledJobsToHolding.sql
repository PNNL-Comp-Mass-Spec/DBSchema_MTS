/****** Object:  StoredProcedure [dbo].[SetReversedAndScrambledJobsToHolding] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure SetReversedAndScrambledJobsToHolding
/****************************************************
**
**	Desc:	Looks for jobs that were searched against a reversed or
**			scrambled protein database that are in state @ProcessStateMatch
**			Updates their state to 6 = Holding
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	08/02/2006
**			02/07/2007 mem - Now calling DeleteSeqCandidateDataForSkippedJobs
**			07/23/2009 mem - Now posting log entries for the jobs that are set to holding
**			11/07/2009 mem - Now also looking for decoy searches where all of the loaded search results are reversed/scrambled proteins
**			07/23/2010 mem - Added 'xxx.%' as a potential prefix for reversed proteins
**    
*****************************************************/
(
	@ProcessStateMatch int = 25,
	@NextProcessState int = 6,
	@numJobsProcessed int=0 OUTPUT
)
As
	Set NoCount On
	
	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Declare @JobCount int
	
	Declare @message varchar(512)
	Set @message = ''

	Set @numJobsProcessed = 0

	CREATE TABLE #TmpJobsToHold (
		Job int NOT NULL
	)
	
	-- Look for jobs that were searched against a reversed or scrambled protein collection
	INSERT INTO #TmpJobsToHold (Job)
	SELECT Job
	FROM T_Analysis_Description
	WHERE Process_State = @ProcessStateMatch AND (
			Organism_DB_Name LIKE '%scrambled.fasta' OR
			Organism_DB_Name LIKE '%reversed.fasta' OR
			Protein_Options_List LIKE 'seq[_]direction=reversed%' OR
			Protein_Options_List LIKE 'seq[_]direction=scrambled%'
		  )
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	Set @JobCount = @myRowCount

	-- Look for jobs where all of the search results map to reversed/scrambled proteins
	INSERT INTO #TmpJobsToHold (Job)
	SELECT Job
	FROM ( SELECT Pep.Analysis_ID AS Job,
	              COUNT(*) AS PeptideCount,
	              SUM(CASE WHEN Prot.Reference LIKE 'reversed[_]%' OR	-- MTS reversed proteins
				                Prot.Reference LIKE 'scrambled[_]%' OR	-- MTS scrambled proteins
				                Prot.Reference LIKE '%[:]reversed' OR	-- X!Tandem decoy proteins
				                Prot.Reference LIKE 'xxx.%'				-- Inspect reversed/scrambled proteins
				           THEN 1
	                       ELSE 0 END) AS DecoyCount
	       FROM T_Peptides Pep
	            INNER JOIN T_Peptide_to_Protein_Map PPM
	              ON Pep.Peptide_ID = PPM.Peptide_ID
	            INNER JOIN T_Proteins Prot
	              ON PPM.Ref_ID = Prot.Ref_ID
	            INNER JOIN T_Analysis_Description TAD
	              ON Pep.Analysis_ID = TAD.Job
	       WHERE TAD.Process_State = @ProcessStateMatch AND 
	             NOT TAD.Job IN (SELECT Job FROM #TmpJobsToHold)
	       GROUP BY Pep.Analysis_ID 
	       ) LookupQ
	WHERE PeptideCount = DecoyCount
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	Set @JobCount = @JobCount + @myRowCount

	If @JobCount > 0
	Begin
		UPDATE T_Analysis_Description
		SET Process_State = @NextProcessState,
		    Last_Affected = GetDate()
		FROM T_Analysis_Description TAD
		     INNER JOIN #TmpJobsToHold J
		       ON TAD.Job = J.Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error updating jobs to state ' + Convert(varchar(9), IsNull(@NextProcessState, 0)) + ' in T_Analysis_Description'
			execute PostLogEntry 'Error', @message, 'SetReversedAndScrambledJobsToHolding'
			goto done
		End
		Else
		Begin
			Set @numJobsProcessed = @myRowCount
			
			INSERT INTO T_Log_Entries (posted_by, posting_time, type, message)		
			SELECT 'SetReversedAndScrambledJobsToHolding',
				GetDate(), 
				'Normal',
				'Changed job ' + Convert(varchar(12), job) + ' to state 6=Holding because it used a scrambled or reversed protein collection (or because all search results are from reversed/scrambled proteins)'
			FROM #TmpJobsToHold
			ORDER BY Job
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
		End
	End
	
	-- Now delete any data in the T_Seq_Candidate tables that is mapped to any old jobs that are in state @NextProcessState
	exec DeleteSeqCandidateDataForSkippedJobs @ProcessStateMatch = @NextProcessState, @InfoOnly = 0, @message = @message output
	
Done:
	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[SetReversedAndScrambledJobsToHolding] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[SetReversedAndScrambledJobsToHolding] TO [MTS_DB_Lite] AS [dbo]
GO
