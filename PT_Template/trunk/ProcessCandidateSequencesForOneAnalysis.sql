/****** Object:  StoredProcedure [dbo].[ProcessCandidateSequencesForOneAnalysis] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ProcessCandidateSequencesForOneAnalysis
/****************************************************
** 
**	Desc:	Uses T_Seq_Candidates and T_Seq_Candidate_ModDetails to 
**			lookup the Seq_ID value for each sequence, populating
**			T_Sequence as needed
**
**			Next, uses T_Seq_Candidate_to_Peptide_Map to update the 
**			Seq_ID values in T_Peptides for the given analysis job
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	01/15/2006
**			01/18/2006 mem - Updated @logLevel threshold for some of the messages
**			05/03/2006 mem - Switched Master_Sequences location from Albert to Daffy
**			05/13/2006 mem - Added statement: Set XACT_ABORT On
**			06/07/2006 mem - Now creating temporary tables in the Master_Sequences DB for transferring candidate sequences to process
**			06/08/2006 mem - Now using GetOrganismDBFileInfo to lookup the OrganismDBFileID or ProteinCollectionFileID value for the given job
**			06/21/2006 mem - Now checking for sequences modified two or more times on the same residue with the same modification; if found, posting a Warning entry to the log
**			11/21/2006 mem - Switched Master_Sequences location from Daffy to ProteinSeqs
**			11/27/2006 mem - Added support for option SkipPeptidesFromReversedProteins
**			11/30/2006 mem - Implemented Try...Catch error handling
**			12/01/2006 mem - Changed the minimum log level for the "Update" progress messages to be 2 rather than 1
**			05/23/2007 mem - Now passing source server and database name to ProcessCandidateSequences
**    
*****************************************************/
(
	@NextProcessState int = 30,
	@job int,
	@count int=0 output,
	@message varchar(512)='' output
)
As
	Set NoCount On
	
	-- This statement is needed because the Master_Sequences database may be located on another server
	Set XACT_ABORT On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'
	
	set @count = 0	
	set @message = ''

	declare @MasterSequencesServerName varchar(64)
	set @MasterSequencesServerName = 'ProteinSeqs'
	
	declare @jobStr varchar(12)
	set @jobStr = cast(@job as varchar(12))

	declare @OrganismDBFileID int
	declare @ProteinCollectionFileID int
	
	declare @DeleteTempTables tinyint
	declare @processCount int
	declare @sequencesAdded int
	declare @UndefinedSeqIDCount int
	declare @SkipPeptidesFromReversedProteins tinyint

	set @DeleteTempTables = 0
	set @processCount = 0
	set @sequencesAdded = 0
	set @UndefinedSeqIDCount = 0

	declare @CreateTempCandidateSequenceTables tinyint
	declare @CandidateTablesContainJobColumn tinyint
	
	declare @CandidateSequencesTableName varchar(256)
	declare @CandidateModDetailsTableName varchar(256)

	declare @MatchCount int
	declare @messageAddnl varchar(256)

	declare @Sql varchar(1024)

	declare @SourceDatabase varchar(256)
	Set @SourceDatabase = @@ServerName + '.' + DB_Name()
	
	declare @logLevel int
	set @logLevel = 1		-- Default to normal logging

	Begin Try
		Set @CurrentLocation = 'Lookup settings in T_Process_Step_Control'
		
		--------------------------------------------------------------
		-- Lookup the LogLevel state 
		-- 0=Off, 1=Normal, 2=Verbose, 3=Debug
		--------------------------------------------------------------
		--
		SELECT @logLevel = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'LogLevel')

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
		
		If @SkipPeptidesFromReversedProteins <> 0
		Begin
			-- Need to delete entries from the T_Seq_Candidate tables that
			-- map only to peptides with State_ID = 2 in T_Peptides

			Set @CurrentLocation = 'Delete entries from the T_Seq_Candidate tables that map only to peptides with State_ID = 2'
			
			CREATE TABLE #Tmp_LocalSeqsToDelete (
				Seq_ID_Local int NOT NULL
			)
			
			INSERT INTO #Tmp_LocalSeqsToDelete (Seq_ID_Local)
			SELECT Seq_ID_Local
			FROM (	SELECT SC.Seq_ID_Local, COUNT(*) AS Peptide_Count, 
						SUM(CASE WHEN State_ID = 2 THEN 1 ELSE 0 END) AS Rev_Peptide_Count
					FROM T_Peptides Pep INNER JOIN
						T_Seq_Candidate_to_Peptide_Map SCPM ON Pep.Peptide_ID = SCPM.Peptide_ID INNER JOIN
						T_Seq_Candidates SC ON SCPM.Job = SC.Job AND SCPM.Seq_ID_Local = SC.Seq_ID_Local
					WHERE Pep.Analysis_ID = @Job
					GROUP BY SC.Seq_ID_Local
				) SeqCandidateQ
			WHERE Rev_Peptide_Count > 0 AND
				Peptide_Count = Rev_Peptide_Count
			--
			SELECT @myRowcount = @@rowcount, @myError = @@error

			If @myError <> 0
			Begin
				Set @message = 'Error Populating #Tmp_LocalSeqsToDelete for job ' + @jobStr + '; error ' + Convert(varchar(12), @myError)
				Goto Done
			End
			
			If @myRowcount > 0
			Begin
				-- Found sequences to delete
				Set @CurrentLocation = 'Delete entries in the T_Seq_Candidate tables using #Tmp_LocalSeqsToDelete'

				DELETE T_Seq_Candidate_ModDetails
				FROM T_Seq_Candidate_ModDetails SCMD INNER JOIN
					#Tmp_LocalSeqsToDelete ON SCMD.Seq_ID_Local = #Tmp_LocalSeqsToDelete.Seq_ID_Local
				WHERE SCMD.Job = @Job
				--
				SELECT @myRowcount = @@rowcount, @myError = @@error

				DELETE T_Seq_Candidate_to_Peptide_Map
				FROM T_Seq_Candidate_to_Peptide_Map SCPM INNER JOIN
					#Tmp_LocalSeqsToDelete ON SCPM.Seq_ID_Local = #Tmp_LocalSeqsToDelete.Seq_ID_Local
				WHERE SCPM.Job = @Job
				--
				SELECT @myRowcount = @@rowcount, @myError = @@error

				DELETE T_Seq_Candidates
				FROM T_Seq_Candidates SC INNER JOIN
					#Tmp_LocalSeqsToDelete ON SC.Seq_ID_Local = #Tmp_LocalSeqsToDelete.Seq_ID_Local
				WHERE SC.Job = @Job
				--
				SELECT @myRowcount = @@rowcount, @myError = @@error
				
				-- Post a log entry
				set @message = 'Skipping ' + Convert(varchar(12), @myRowcount) + ' unique peptides for job ' + @jobStr + ' since they map only to reversed or scrambled proteins'

				execute PostLogEntry 'Warning', @message, 'ProcessCandidateSequencesForOneAnalysis'
				set @message = ''
				
			End
		End
		
		------------------------------------------------------------------
		-- Lookup the number of proteins and residues in Organism DB file (aka the FASTA file)
		--  or Protein Collection used for this analysis job
		-- Note that GetOrganismDBFileInfo will post an error to the log if the job
		--  has an unknown Fasta file or Protein Collection List
		------------------------------------------------------------------
		--
		Set @CurrentLocation = 'Call GetOrganismDBFileInfo for job ' + @jobStr
		
		Exec @myError = GetOrganismDBFileInfo @job, 
								@OrganismDBFileID  = @OrganismDBFileID OUTPUT,
								@ProteinCollectionFileID = @ProteinCollectionFileID OUTPUT
		
		If @myError <> 0
		Begin
			-- GetOrganismDBFileInfo returned an error: abort processing 
			-- Note that UpdateSequenceModsForAvailableAnalyses looks for the text "Error calling GetOrganismDBFileInfo"
			-- If found, it will not re-post an error to the log
			Set @myError = 51112
			Set @message = 'Error calling GetOrganismDBFileInfo (Code ' + Convert(varchar(12), @myError) + ')'
			Goto Done
		End
		
		Set @OrganismDBFileID = IsNull(@OrganismDBFileID, 0)
		Set @ProteinCollectionFileID = IsNull(@ProteinCollectionFileID, 0)


		Set @CurrentLocation = 'Define @CandidateSequencesTableName and @CandidateModDetailsTableName'

		-- Effective 2006-06-07, we are now creating the temp candidate sequence tables on the remote server
		Set @CreateTempCandidateSequenceTables = 1
		
		If @CreateTempCandidateSequenceTables = 0
		Begin
			-- Do not create temporary candidate sequence tables; simply use the T_Seq_Candidate tables in this database
			Set @CandidateTablesContainJobColumn = 1
			Set @CandidateSequencesTableName = @@ServerName + '.[' + DB_Name() + '].dbo.T_Seq_Candidates'
			Set @CandidateModDetailsTableName = @@ServerName + '.[' + DB_Name() + '].dbo.T_Seq_Candidate_ModDetails'
		End
		Else
		Begin
			-----------------------------------------------------------
			-- Create two tables on the master sequences server to cache the data to process
			-----------------------------------------------------------
			--
			Set @message = 'Call Master_Sequences.dbo.CreateTempSequenceTables for job ' + @jobStr
			Set @CurrentLocation = @message

			Set @CandidateTablesContainJobColumn = 0
			
			-- Warning: Update @MasterSequencesServerName above if changing from ProteinSeqs to another computer
			exec ProteinSeqs.Master_Sequences.dbo.CreateTempCandidateSequenceTables @CandidateSequencesTableName output, @CandidateModDetailsTableName output
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				set @message = 'Problem calling CreateTempCandidateSequenceTables to create the temporary sequence tables for job ' + @jobStr
				goto Done
			end
			else
				set @DeleteTempTables = 1

			-----------------------------------------------------------
			-- Populate @CandidateSequencesTableName with the candidate sequences
			-----------------------------------------------------------
			--
			Set @CurrentLocation = 'Populate ' + @MasterSequencesServerName + '.' + @CandidateSequencesTableName + ' with candidate sequences for job ' + @jobStr
			
			Set @Sql = ''
			Set @Sql = @Sql + ' INSERT INTO ' + @MasterSequencesServerName + '.' + @CandidateSequencesTableName
			set @Sql = @Sql +       ' (Seq_ID_Local, Clean_Sequence, Mod_Count, Mod_Description, Monoisotopic_Mass)'
			Set @Sql = @Sql + ' SELECT Seq_ID_Local, Clean_Sequence, Mod_Count, Mod_Description, Monoisotopic_Mass'
			Set @Sql = @Sql + ' FROM T_Seq_Candidates'
			Set @Sql = @Sql + ' WHERE Job = ' + @jobStr
			--
			Exec (@Sql)
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				set @message = 'Problem populating ' + @MasterSequencesServerName + ' with the candidate sequences to process for job ' + @jobStr
				goto Done
			end

			-----------------------------------------------------------
			-- See if any of the sequences has a residue modified more than once with the same modification
			-- If it does, post a warning to the log
			-----------------------------------------------------------
			--
			Set @CurrentLocation = 'Check for invalid residue modification'
			Set @MatchCount = 0
			SELECT @MatchCount = COUNT(*) 
			FROM (	SELECT Seq_ID_Local, Mass_Correction_Tag, [Position]
					FROM T_Seq_Candidate_ModDetails
					WHERE (Job = @job)
					GROUP BY Seq_ID_Local, Mass_Correction_Tag, [Position]
					HAVING COUNT(*) > 1
				) LookupQ
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			If @MatchCount > 0
			Begin
				set @message = 'Warning: Found ' + Convert(varchar(9), @MatchCount) + ' sequences in job ' + @jobStr + ' with sequences modified two or more times on the same residue with the same modification'

				Set @messageAddnl = ''
				SELECT @messageAddnl =
						'First entry is ' + Clean_Sequence + ' with mod ' + RTRIM(Mass_Correction_Tag) +
						' on residue #' + CONVERT(varchar(9), [Position]) +
						', occurring ' +  CONVERT(varchar(9), OccurrenceCount) + ' times'
				FROM (	SELECT TOP 1 SCMD.Position, SC.Clean_Sequence, 
									SCMD.Mass_Correction_Tag, COUNT(*) AS OccurrenceCount
						FROM T_Seq_Candidate_ModDetails SCMD INNER JOIN
							T_Seq_Candidates SC ON SCMD.Job = SC.Job AND SCMD.Seq_ID_Local = SC.Seq_ID_Local
						WHERE (SCMD.Job = @job)
						GROUP BY SCMD.Seq_ID_Local, SCMD.Mass_Correction_Tag, SCMD.Position, SC.Clean_Sequence
						HAVING COUNT(*) > 1
					) LookupQ
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				If Len(IsNull(@messageAddnl, '')) > 0 
					Set @message = @message + '; ' + @messageAddnl
					
				execute PostLogEntry 'Warning', @message, 'ProcessCandidateSequencesForOneAnalysis'
				set @message = ''
			End
			
			-----------------------------------------------------------
			-- Populate @CandidateModDetailsTableName with the data to parse
			-----------------------------------------------------------
			--
			Set @CurrentLocation = 'Populate ' + @MasterSequencesServerName + '.' + @CandidateModDetailsTableName + ' with candidate mod details'
			Set @Sql = ''
			Set @Sql = @Sql + ' INSERT INTO ' + @MasterSequencesServerName + '.' + @CandidateModDetailsTableName
			set @Sql = @Sql +       ' (Seq_ID_Local, Mass_Correction_Tag, Position)'
			Set @Sql = @Sql + ' SELECT Seq_ID_Local, Mass_Correction_Tag, Position'
			Set @Sql = @Sql + ' FROM T_Seq_Candidate_ModDetails'
			Set @Sql = @Sql + ' WHERE Job = ' + @jobStr
			--
			Exec (@Sql)
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				set @message = 'Problem populating ' + @MasterSequencesServerName + ' with the candidate sequence mod details for job ' + @jobStr
				goto Done
			end
		End

		-----------------------------------------------------------
		-- Call ProcessCandidateSequences to process the data in the temporary sequence tables
		-----------------------------------------------------------
		--
		set @message = 'Call Master_Sequences.dbo.ProcessCandidateSequences for job ' + @jobStr
		Set @CurrentLocation = @message
		If @logLevel >= 1
			execute PostLogEntry 'Progress', @message, 'ProcessCandidateSequencesForOneAnalysis'
		--
		exec @myError = ProteinSeqs.Master_Sequences.dbo.ProcessCandidateSequences @OrganismDBFileID, @ProteinCollectionFileID,
																@CandidateSequencesTableName, @CandidateModDetailsTableName, 
																@CandidateTablesContainJobColumn = @CandidateTablesContainJobColumn,
																@Job = @Job, 
																@SourceDatabase = @SourceDatabase,
																@count = @processCount output, 
																@message = @message output
		--
		if @myError <> 0
		begin
			If Len(@message) = 0
				set @message = 'Error with ' + @CurrentLocation + ': ' + convert(varchar(12), @myError)
			else
				set @message = 'Error with ' + @CurrentLocation + ': ' + @message
				
			goto Done
		end
		
		If @CreateTempCandidateSequenceTables <> 0
		Begin
			-----------------------------------------------------------
			-- Update the Seq_ID values in T_Seq_Candidates using the
			-- tables on the remote server
			-----------------------------------------------------------
			Set @CurrentLocation = 'UPDATE T_Seq_Candidates using Seq_ID values in ' + @MasterSequencesServerName + '.' + @CandidateSequencesTableName
			
			Set @Sql = ''
			Set @Sql = @Sql + ' UPDATE T_Seq_Candidates'
			Set @Sql = @Sql + ' SET Seq_ID = MSeqData.Seq_ID'
			Set @Sql = @Sql + ' FROM T_Seq_Candidates TSC INNER JOIN'
			Set @Sql = @Sql +  ' ' + @MasterSequencesServerName + '.' + @CandidateSequencesTableName + ' MSeqData '
			set @Sql = @Sql +    ' ON TSC.Seq_ID_Local = MSeqData.Seq_ID_Local AND TSC.Job = ' + @jobStr
			--
			Exec (@Sql)
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			if @myError <> 0
			begin
				set @message = 'Error updating T_Seq_Candidates with the Seq_ID values for job ' + @jobStr
				goto Done
			end
		End
	
		-----------------------------------------------------------
		-- Validate that all of the sequences have Seq_ID values for this job
		-----------------------------------------------------------
		Set @CurrentLocation = 'Validate that all of the sequences have Seq_ID values for job ' + @jobStr
		Set @UndefinedSeqIDCount = 0
		
		SELECT @UndefinedSeqIDCount = Count(*)
		FROM T_Seq_Candidates
		WHERE Job = @Job AND Seq_ID IS NULL
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @UndefinedSeqIDCount > 0
		Begin
			set @message = 'Found ' + Convert(varchar(12), @UndefinedSeqIDCount) + ' sequences with undefined Seq_ID values in T_Seq_Candidates for job ' + @jobStr
			set @myError = 51113
			Goto Done
		End


		-----------------------------------------------------------
		-- Flag entries in T_Seq_Candidates that need to be added to T_Sequence
		-- First, reset Add_Sequence to 0 for entries from @Job
		-- Then, set Add_Sequence to 1 for new sequences
		-----------------------------------------------------------
		--
		set @message = 'Flag entries in T_Seq_Candidates that need to be added to T_Sequence for job ' + @jobStr
		Set @CurrentLocation = 'Clear T_Seq_Candidates.Add_Sequence for job ' + @jobStr
		If @logLevel >= 2
			execute PostLogEntry 'Progress', @message, 'ProcessCandidateSequencesForOneAnalysis'
		--
		UPDATE T_Seq_Candidates 
		SET Add_Sequence = 0
		FROM T_Seq_Candidates
		WHERE Job = @Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		-- ToDo: Possibly start a transaction here and end it after inserting new sequences into T_Sequence
		
		Set @CurrentLocation = @message
		UPDATE T_Seq_Candidates 
		SET Add_Sequence = 1
		FROM T_Seq_Candidates TSC LEFT OUTER JOIN
			T_Sequence S ON TSC.Seq_ID = S.Seq_ID
		WHERE TSC.Job = @Job AND S.Seq_ID IS NULL
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		-----------------------------------------------------------
		-- Add the new sequences to T_Sequence
		-----------------------------------------------------------
		--
		set @message = 'Add new sequences to T_Sequence for job ' + @jobStr
		Set @CurrentLocation = @message
		If @logLevel >= 1
			execute PostLogEntry 'Progress', @message, 'ProcessCandidateSequencesForOneAnalysis'
		--
		INSERT INTO T_Sequence (Seq_ID, Clean_Sequence, Mod_Count, Mod_Description, Monoisotopic_Mass)
		SELECT Seq_ID, Clean_Sequence, Mod_Count, Mod_Description, Monoisotopic_Mass
		FROM T_Seq_Candidates
		WHERE Job = @Job AND Add_Sequence = 1
		--
		SELECT @myError = @@error, @myRowcount = @@rowcount
		--
		Set @sequencesAdded = @myRowCount
		
		
		-----------------------------------------------------------
		-- Update T_Peptides
		-----------------------------------------------------------
		--
		set @message = 'Update Seq_ID in T_Peptides for job ' + @jobStr
		Set @CurrentLocation = @message
		If @logLevel >= 2
			execute PostLogEntry 'Progress', @message, 'ProcessCandidateSequencesForOneAnalysis'
		--
		UPDATE T_Peptides
		SET Seq_ID = TSC.Seq_ID
		FROM T_Seq_Candidates TSC INNER JOIN
			T_Seq_Candidate_to_Peptide_Map TSCPM ON 
			TSC.Job = TSCPM.Job AND TSC.Seq_ID_Local = TSCPM.Seq_ID_Local INNER JOIN
			T_Peptides P ON TSCPM.Peptide_ID = P.Peptide_ID
		WHERE TSC.Job = @Job
		--
		SELECT @myError = @@error, @myRowcount = @@rowcount
		--
		Set @processCount = @myRowCount


		-----------------------------------------------------------
		-- Update Cleavage_State_Max in T_Sequence for the peptides present in this job
		-----------------------------------------------------------
		--	
		set @message = 'Update Cleavage_State_Max in T_Sequence for job ' + @jobStr
		Set @CurrentLocation = @message
		If @logLevel >= 2
			execute PostLogEntry 'Progress', @message, 'ProcessCandidateSequencesForOneAnalysis'
		--
		UPDATE T_Sequence
		SET Cleavage_State_Max = LookupQ.Cleavage_State_Max
		FROM T_Sequence S INNER JOIN (
			SELECT P.Seq_ID, MAX(ISNULL(PPM.Cleavage_State, 0)) AS Cleavage_State_Max
			FROM T_Peptides P INNER JOIN
				T_Peptide_to_Protein_Map PPM ON 
				P.Peptide_ID = PPM.Peptide_ID INNER JOIN
				T_Sequence ON P.Seq_ID = T_Sequence.Seq_ID
			WHERE P.Analysis_ID = @job
			GROUP BY P.Seq_ID
			) LookupQ ON S.Seq_ID = LookupQ.Seq_ID
		WHERE LookupQ.Cleavage_State_Max > S.Cleavage_State_Max OR
			S.Cleavage_State_Max IS NULL
		--
		SELECT @myRowcount = @@rowcount, @myError = @@error


		-----------------------------------------------------------
		-- Delete entries from the T_Seq_Candidate tables for this job
		-----------------------------------------------------------
		--	
		set @message = 'Delete entries from the T_Seq_Candidate tables for job ' + @jobStr
		Set @CurrentLocation = @message
		If @logLevel >= 2
			execute PostLogEntry 'Progress', @message, 'ProcessCandidateSequencesForOneAnalysis'
		--
		DELETE FROM T_Seq_Candidate_ModDetails WHERE Job = @job
		--
		SELECT @myRowcount = @@rowcount, @myError = @@error
		--
		If @myError <> 0
		Begin
			set @message = 'Error deleting entries from T_Seq_Candidate_ModDetails for job ' + @jobStr
			Goto Done
		End

		DELETE FROM T_Seq_Candidate_to_Peptide_Map WHERE Job = @job
		--
		SELECT @myRowcount = @@rowcount, @myError = @@error
		--
		If @myError <> 0
		Begin
			set @message = 'Error deleting entries from T_Seq_Candidate_to_Peptide_Map for job ' + @jobStr
			Goto Done
		End

		DELETE FROM T_Seq_Candidates WHERE Job = @job
		--
		SELECT @myRowcount = @@rowcount, @myError = @@error
		--
		If @myError <> 0
		Begin
			set @message = 'Error deleting entries from T_Seq_Candidates for job ' + @jobStr
			Goto Done
		End


		-----------------------------------------------------------
		-- Update state of analysis job
		-----------------------------------------------------------
		--
		Set @CurrentLocation = 'Update state for job ' + @jobStr + ' to ' + Convert(varchar(12), @NextProcessState)
		Exec SetProcessState @job, @NextProcessState

		set @count = @processCount
		set @message = 'Peptide sequence mods updated for job ' + @jobStr + '; Sequences processed: ' + convert(varchar(11), @processCount) + '; New sequences added: ' + convert(varchar(11), @sequencesAdded)
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'ProcessCandidateSequencesForOneAnalysis')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch		
	
Done:

	-----------------------------------------------------------
	-- Delete the temporary sequence tables, since no longer needed
	-----------------------------------------------------------
	--
	If @CreateTempCandidateSequenceTables <> 0 And @DeleteTempTables = 1
	Begin
		Begin Try
			Set @CurrentLocation = 'Delete temporary tables ' + @CandidateSequencesTableName + ' and ' + @CandidateModDetailsTableName
			exec ProteinSeqs.Master_Sequences.dbo.DropTempSequenceTables @CandidateSequencesTableName, @CandidateModDetailsTableName
		End Try
		Begin Catch
			-- Error caught
			Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'ProcessCandidateSequencesForOneAnalysis')
			exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
									@ErrorNum = @myError output, @message = @message output
		End Catch
	End

	Return @myError


GO
