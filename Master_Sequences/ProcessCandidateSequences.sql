/****** Object:  StoredProcedure [dbo].[ProcessCandidateSequences] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.ProcessCandidateSequences
/****************************************************
** 
**	Desc:
**		Processes the candidate sequences in the given table 
**		(typically located in the Master_Seq_Scratch DB).  Assigns
**		a Seq_ID value to each sequence using the sequence, Mod_Count, and
**		Mod_Description information to determine If the sequence is new
**
**		The peptide sequences table must contain the columns Seq_ID_Local,
**		  Clean_Sequence, Mod_Count, Mod_Description, Monoisotopic_Mass, and Seq_ID
**
**		A second table must also be provided containing the modification details for
**		the candidate sequences.  This table must contain columns Seq_ID_Local, 
**		Mass_Correction_Tag, and Position
**
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	01/15/2006
**			06/07/2006 mem - Added support for Protein Collection File IDs and removed input parameter @organismDBName
**			06/21/2006 mem - Expanded the error message displayed when the mod counts do not agree
**			05/23/2007 mem - Added parameters @SourceDatabase, @NewSequencesBatchSize, and @PreviewSql
**						   - Added a queuing mechanism that prevents multiple processes from searching/updating T_Sequences using candidate sequence tables
**						   - Switched to Try/Catch error handling
**			05/02/2008 mem - Now checking for Queue_State changing from 1 to another value by an external process
**			11/30/2012 mem - Now using fuzzy-matching for peptides with unknown-named mods
**			12/06/2012 mem - No longer using fuzzy-matching since peptides with unknown mass values are now named using the monoisotopic mass of the modification
**    
*****************************************************/
(
	@OrganismDBFileID int=0,							-- Organism DB file ID; If @OrganismDBFileID is non-zero, then @ProteinCollectionFileID is ignored
	@ProteinCollectionFileID int=0,						-- Protein collection file ID
	@CandidatesSequencesTableName varchar(256),			-- Table with candidate peptide sequences, populates the Seq_ID column in this table
	@CandidateModDetailsTableName varchar(256),			-- Table with the modification details for each sequence
	@CandidateTablesContainJobColumn tinyint,			-- Set to 1 if the candidate tables contain a Job column and thus need to be filtered on @Job
	@Job int,
	@SourceDatabase varchar(256) = '',
	@NewSequencesBatchSize int = 10000,
	@PreviewSql tinyint = 0,							-- Set to 1 to preview the Sql that would be used; set to 2 to Preview the Sql and update the source tables with existing peptides in T_Sequence but not add any new peptides to T_Sequence
	@count int=0 output,								-- Number of peptides processed
	@message varchar(256) = '' output	
)
As
	Set NoCount On
	
	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Declare @jobStr varchar(12)
	Set @jobStr = cast(@job as varchar(12))

	Declare @SleepTimeSeconds int
	Declare @SleepTime datetime
	
	Set @SleepTimeSeconds = 20
	Set @SleepTime = Convert(datetime, @SleepTimeSeconds/86400.0)

	Declare @ProcessingHistoryEntryIDCurrent int
	Declare @ProcessingHistoryEntryIDMin int

	Declare @QueueUpdateTimeoutMinutes int
	Set @QueueUpdateTimeoutMinutes = 90
	
	Declare @S nvarchar(max)
	Declare @SeqIDLocalFilter nvarchar(1024)
	Declare @ParamDef nvarchar(1024)

	Declare @SCountUnMatched nvarchar(max)
	Declare @ParamDefCountUnmatched nvarchar(1024)
	
	Declare @Continue tinyint
	Declare @UniqueIDMin int
	Declare @QueueState int
	
	Declare @MatchCount int
	Declare @NewSequenceCountExpected int
	Declare @NewSequenceCountAdded int
	Declare @MismatchCount int
	Declare @messageAddnl varchar(256)

	Declare @transName varchar(32)


	Declare @CallingProcName varchar(128)
	Declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		-----------------------------------------------------------
		-- Validate the Inputs
		-----------------------------------------------------------

		Set @CandidatesSequencesTableName = IsNull(@CandidatesSequencesTableName, '')
		Set @CandidateModDetailsTableName = IsNull(@CandidateModDetailsTableName, '')
		If Len(LTrim(RTrim(@CandidatesSequencesTableName))) = 0
		Begin
			Set @message = '@CandidatesSequencesTableName cannot be null'
			Set @myError = 53005
			Goto Done
		End

		If Len(LTrim(RTrim(@CandidateModDetailsTableName))) = 0
		Begin
			Set @message = '@CandidateModDetailsTableName cannot be null'
			Set @myError = 53006
			Goto Done
		End
		
		Set @NewSequencesBatchSize = IsNull(@NewSequencesBatchSize, 10000)
		If @NewSequencesBatchSize < 500
			Set @NewSequencesBatchSize = 500
		
		Set @PreviewSql = IsNull(@PreviewSql, 0)
		If @PreviewSql < 0
			Set @PreviewSql = 1

		Set @count = 0
		Set @message = ''

		-----------------------------------------------------------
		-- Queue this update in T_Candidate_Seq_Processing_History,
		--  then proceed if the earliest queued entry
		-----------------------------------------------------------
		--
		Set @CurrentLocation = 'Queue item in T_Candidate_Seq_Processing_History'

		INSERT INTO T_Candidate_Seq_Processing_History (Candidate_Seqs_Table_Name, Source_Database, Source_Job, Queue_State, Last_Affected)
		VALUES (@CandidatesSequencesTableName, @SourceDatabase, @Job, 1, GetDate())
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error, @ProcessingHistoryEntryIDCurrent = Scope_Identity()
		
		--
		If @ProcessingHistoryEntryIDCurrent Is Null
		Begin
			Set @message = 'Error adding ' + @CandidatesSequencesTableName + ' to T_Candidate_Seq_Processing_History'
			Set @myError = 53007
			Goto Done
		End

		Set @Continue = 1
		While @Continue = 1
		Begin -- <a>
			-----------------------------------------------------------
			-- Look in T_Candidate_Seq_Processing_History for any entries 
			--  where Queue_State is 1 or 2 but Last_Affected is more than 
			--  @QueueUpdateTimeoutMinutes minutes ago; if found, then 
			--  update Queue_State to 5=Failed
			-----------------------------------------------------------
			--
			UPDATE T_Candidate_Seq_Processing_History
			SET Queue_State = 5, Status_Message = 'Queue_State changed to 5 since last updated more than ' + Convert(varchar(12), @QueueUpdateTimeoutMinutes) + ' minutes before ' + Convert(varchar(32), GetDate())
			WHERE Queue_State IN (1, 2) AND 
				  DateDiff(minute, Last_Affected, GetDate()) > @QueueUpdateTimeoutMinutes
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			If @myRowCount > 0
			Begin
				Set @message = 'Set Queue_State to 5 for ' + Convert(varchar(12), @myRowCount) + ' entry(s) in T_Candidate_Seq_Processing_History that are in State 1 or 2 and last updated more than ' + Convert(varchar(12), @QueueUpdateTimeoutMinutes) + ' minutes ago'
				exec PostLogEntry 'Error', @message, 'ProcessCandidateSequences'
				Set @message = ''
			End

			-- See if any entries currently have Queue_State = 2
			Set @MatchCount = 0
			SELECT @MatchCount = COUNT(*)
			FROM T_Candidate_Seq_Processing_History
			WHERE Queue_State = 2
			
			If @MatchCount = 0
			Begin -- <b>
				-- No entries have Queue_State 2
				-- Lookup the smallest Entry_ID with Queue_State 1
				
				Set @transName = 'CheckQueue'
				Begin Transaction @transName
				
				SELECT @ProcessingHistoryEntryIDMin = MIN(Entry_ID)
				FROM T_Candidate_Seq_Processing_History
				WHERE Queue_State = 1
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				
				If @myRowCount = 0
				Begin
					rollback transaction @transName
				
					Set @myError = 53008
					Set @Message = 'No entries found in T_Candidate_Seq_Processing_History with Queue_State = 1; this is unexpected, since entry ' + Convert(varchar(12), @ProcessingHistoryEntryIDCurrent) + ' should have Queue_State = 1'
					
					Goto Done
				End
				
				If @ProcessingHistoryEntryIDMin = @ProcessingHistoryEntryIDCurrent
				Begin
					-- This entry is now the earliest in the queue with state 1
					-- Change its queue state to 2
					--
					UPDATE T_Candidate_Seq_Processing_History
					SET Queue_State = 2, Last_Affected = GetDate(), Processing_Start = GetDate()
					WHERE Entry_ID = @ProcessingHistoryEntryIDCurrent
					--
					Set @Continue = 0
				End

				Commit Transaction @transName
				Set @transName = ''
				
				If @ProcessingHistoryEntryIDMin < @ProcessingHistoryEntryIDCurrent
				Begin
					-- Other entries before this entry are queued or processing
					Set @Continue = 1
				End
				
				If @ProcessingHistoryEntryIDMin > @ProcessingHistoryEntryIDCurrent
				Begin -- <c>
					-- This entry is no longer the earliest entry in T_Candidate_Seq_Processing_History
					-- with Queue_State = 1; this is an unexpected state
					
					Set @message = 'Queue_State changed from 1 by an external process; aborting at ' + Convert(varchar(32), GetDate())
					
					UPDATE T_Candidate_Seq_Processing_History
					SET Queue_State = 5, Status_Message = @message
					WHERE Entry_ID = @ProcessingHistoryEntryIDCurrent AND Queue_State <> 5
					
					Set @myError = 53009
					Set @message = 'Candidate Seq Processing History Entry_ID ' + Convert(varchar(12), @ProcessingHistoryEntryIDCurrent) + ' had its ' + @message
					
					Goto Done
				End -- </c>
			End -- </b>
			
			If @Continue = 1
			Begin
				-- Delay for @SleepTime seconds, then update Last_Affected in T_Candidate_Seq_Processing_History
				--
				WaitFor Delay @SleepTime 

				UPDATE T_Candidate_Seq_Processing_History
				SET Last_Affected = GetDate()
				WHERE Entry_ID = @ProcessingHistoryEntryIDCurrent AND Queue_State = 1
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				If @myRowCount = 0
				Begin
					-- Update was not successful; either entry @ProcessingHistoryEntryIDCurrent is no longer in the table
					--  or (more likely) its Queue_State value was changed by another process
					-- Determine the reason, then abort processing
					
					Set @QueueState = 0
					SELECT @QueueState = Queue_State
					FROM T_Candidate_Seq_Processing_History
					WHERE Entry_ID = @ProcessingHistoryEntryIDCurrent
					--
					SELECT @myRowCount = @@rowcount, @myError = @@error

					If @myRowCount = 0
						Set @Message = 'Entry_ID ' + Convert(varchar(12), @ProcessingHistoryEntryIDCurrent) + ' is not present in T_Candidate_Seq_Processing_History; this is unexpected.  Aborting processing.'
					Else
						Set @Message = 'Entry_ID ' + Convert(varchar(12), @ProcessingHistoryEntryIDCurrent) + ' has had its T_Candidate_Seq_Processing_History.Queue_State value changed from 1 to ' + Convert(varchar(12), @QueueState) + ' by an external process; this is unexpected.  Aborting processing.'
						
					Set @myError = 53010
					Goto Done

				End
			End
			
		End -- </a>
	
	
		-----------------------------------------------------------
		-- Clear the Seq_ID values in @CandidatesSequencesTableName
		-----------------------------------------------------------
		--
		Set @CurrentLocation = 'Clear the Seq_ID values in @CandidatesSequencesTableName'
		If @PreviewSql >= 1
			print @CurrentLocation
		
		Set @S = ''
		Set @S = @S + ' UPDATE ' + @CandidatesSequencesTableName
		Set @S = @S + ' Set Seq_ID = NULL'
		Set @S = @S + ' FROM ' + @CandidatesSequencesTableName + ' SC'
		Set @S = @S + ' WHERE NOT SC.Seq_ID IS NULL'
		If @CandidateTablesContainJobColumn <> 0
			Set @S = @S +   ' AND SC.Job = ' + @jobStr
		--
		If @PreviewSql >= 1
			Print @S
		If @PreviewSql <> 1
			Exec (@S)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error


		-----------------------------------------------------------
		-- Count the number of sequences to be processed
		-----------------------------------------------------------
		--
		Set @S = ''
		Set @S = @S + ' SELECT @MatchCount = COUNT(*) '
		Set @S = @S + ' FROM ' + @CandidatesSequencesTableName + ' SC '
		If @CandidateTablesContainJobColumn <> 0
			Set @S = @S +   ' WHERE SC.Job = ' + @jobStr
		--
		Set @ParamDef = '@MatchCount int output'
		exec @myError = sp_executesql @S, @ParamDef, @MatchCount = @MatchCount output
		
		UPDATE T_Candidate_Seq_Processing_History
		SET Last_Affected = GetDate(), Sequence_Count = IsNull(@MatchCount, 0)
		WHERE Entry_ID = @ProcessingHistoryEntryIDCurrent
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error


		-----------------------------------------------------------
		-- Update the Seq_ID values for the known sequences
		-- This can be a slow process if the candidate sequences table contains > 50000 sequences
		-----------------------------------------------------------
		--
		Set @CurrentLocation = 'Update the Seq_ID values for the known sequences'
		If @PreviewSql >= 1
			print @CurrentLocation

		Set @transName = 'AssignExistingSeqIDs'
		Begin Transaction @transName

		Set @S = ''
		Set @S = @S + ' UPDATE ' + @CandidatesSequencesTableName
		Set @S = @S + ' Set Seq_ID = MSeqData.Seq_ID'
		Set @S = @S + ' FROM ' + @CandidatesSequencesTableName + ' SC INNER JOIN'
		Set @S = @S +      ' T_Sequence MSeqData ON '
		Set @S = @S +      ' SC.Clean_Sequence = MSeqData.Clean_Sequence AND '
		Set @S = @S +      ' SC.Mod_Count = MSeqData.Mod_Count AND '
		Set @S = @S + ' SC.Mod_Description = MSeqData.Mod_Description'
		If @CandidateTablesContainJobColumn <> 0
			Set @S = @S + ' WHERE SC.Job = ' + @jobStr
		--
		If @PreviewSql >= 1
			Print @S
		If @PreviewSql <> 1
			Exec (@S)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0
		Begin
			rollback transaction @transName
			Set @message = 'Error assigning Seq_ID values to candidate sequences for job ' + @jobStr
			goto Done
		End
		
		Set @count = @myRowCount
		
		-----------------------------------------------------------
		-- Commit changes made so far, then update Last_Affected 
		--  in T_Candidate_Seq_Processing_History
		-----------------------------------------------------------
		Commit Transaction @transName
		Set @transName = ''

		UPDATE T_Candidate_Seq_Processing_History
		SET Last_Affected = GetDate()
		WHERE Entry_ID = @ProcessingHistoryEntryIDCurrent
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		
		-----------------------------------------------------------
		-- Count the number of entries with null Seq_ID Values
		-----------------------------------------------------------
		--		
		Set @CurrentLocation = 'Count the number of entries with null Seq_ID Values'
		If @PreviewSql >= 1
			print @CurrentLocation

		Set @S = ''
		Set @S = @S + ' SELECT @MatchCount = COUNT(*) '
		Set @S = @S + ' FROM ' + @CandidatesSequencesTableName + ' SC '
		Set @S = @S + ' WHERE SC.Seq_ID IS NULL'
		If @CandidateTablesContainJobColumn <> 0
			Set @S = @S +   ' AND SC.Job = ' + @jobStr
		--
		Set @ParamDef = '@MatchCount int output'
		
		Set @SCountUnMatched = @S
		Set @ParamDefCountUnmatched = @ParamDef
		
		exec @myError = sp_executesql @S, @ParamDef, @MatchCount = @NewSequenceCountExpected output
		--
		If @myError <> 0
		Begin
			Set @message = 'Error counting Null Seq_ID values in ' + @CandidatesSequencesTableName + ' for job ' + @jobStr
			goto Done
		End
		
		/*
		** Code in section <a></a1> was added in November 2012 to allow for fuzzy-matching of candidate sequences
		**   with mods of the form "UnkMod00", "Mod00000", or "M0000000"
		** However, shortly thereafter we changed the naming format for unknown mods to have
		**   mod names like "+7.01000" or "-54.9800" and thus the fuzzy matching is no longer required
		*/
		
		/*
		If @NewSequenceCountExpected > 0	
		Begin -- <a1>
		
			-----------------------------------------------------------
			-- Look for candidate sequences with unknown-named mods
			-----------------------------------------------------------
			--
			Set @CurrentLocation = 'Create #Tmp_Peptides_with_UnkMods'
			If @PreviewSql >= 1
				print @CurrentLocation
			
			CREATE TABLE #Tmp_Peptides_with_UnkMods (
				Seq_ID_Local int NOT NULL,
				Clean_Sequence varchar(850) NOT NULL, 
				Mod_Count smallint NOT NULL, 
				Monoisotopic_Mass float NULL
			)

			-- Add an index to #Tmp_Peptides_with_UnkMods
			CREATE UNIQUE CLUSTERED INDEX #IX_Tmp_Peptides_with_UnkMods ON #Tmp_Peptides_with_UnkMods(Seq_ID_Local)
			
			Set @S = ''			
			Set @S = @S + ' INSERT INTO #Tmp_Peptides_with_UnkMods (Seq_ID_Local, Clean_Sequence, Mod_Count, Monoisotopic_Mass)'
			Set @S = @S + ' SELECT SC.Seq_ID_Local, SC.Clean_Sequence, SC.Mod_Count, SC.Monoisotopic_Mass'
			Set @S = @S + ' FROM ' + @CandidatesSequencesTableName + ' SC INNER JOIN '
			Set @S = @S +            @CandidateModDetailsTableName + ' SCMD ON SC.Seq_ID_Local = SCMD.Seq_ID_Local '
			Set @S = @S + ' WHERE SC.Seq_ID IS NULL AND '
			Set @S = @S +       ' IsNull(Monoisotopic_Mass, 0) > 0 AND '
			Set @S = @S +       ' (SCMD.Mass_Correction_Tag LIKE ''UnkMod[0-9][0-9]'' OR '
			Set @S = @S +        ' SCMD.Mass_Correction_Tag LIKE ''Mod[0-9][0-9][0-9][0-9][0-9]'' OR '
			Set @S = @S +        ' SCMD.Mass_Correction_Tag LIKE ''M[0-9][0-9][0-9][0-9][0-9][0-9][0-9]'')'
			
			If @CandidateTablesContainJobColumn <> 0
				Set @S = @S +   ' AND SC.Job = ' + @jobStr + ' AND SCMD.Job = ' + @jobStr
				
			Set @S = @S + ' GROUP BY SC.Seq_ID_Local, SC.Clean_Sequence, SC.Mod_Count, SC.Monoisotopic_Mass'

			If @PreviewSql >= 1
				Print @S
			If @PreviewSql <> 1
				Exec (@S)
		
			If Exists (SELECT * FROM #Tmp_Peptides_with_UnkMods) Or @PreviewSql >= 1
			Begin -- <b1>
			
				-----------------------------------------------------------
				-- Use fuzzy-matching to look for sequences in @CandidatesSequencesTableName that match existing sequences in T_Sequence
				-- with the same clean_sequence, mass, and mod positions
				-----------------------------------------------------------
				--				
				Set @CurrentLocation = 'Create #Tmp_ModDetails_for_SeqIDs_with_UnkMods'
				If @PreviewSql >= 1
					print @CurrentLocation
				
				CREATE TABLE #Tmp_ModDetails_for_SeqIDs_with_UnkMods (
					Seq_ID_Local int NOT NULL,					
					Mass_Correction_Tag char(8) NOT NULL, 
					Position smallint NOT NULL
				)

				-- Add an index to #Tmp_ModDetails_for_SeqIDs_with_UnkMods
				CREATE CLUSTERED INDEX #IX_Tmp_ModDetails_for_SeqIDs_with_UnkMods ON #Tmp_ModDetails_for_SeqIDs_with_UnkMods(Seq_ID_Local)
			
				Set @CurrentLocation = 'Create #Tmp_Candidate_MasterSeqs'
				If @PreviewSql >= 1
					print @CurrentLocation

				CREATE TABLE #Tmp_Candidate_MasterSeqs (
					Seq_ID_Local int NOT NULL,
					Seq_ID int NOT NULL,
					Mass_Correction_Tag char(8) NOT NULL, 
					Position smallint NOT NULL
				)
			
				-- Add an index to #Tmp_Candidate_MasterSeqs
				CREATE CLUSTERED INDEX #IX_Tmp_Candidate_MasterSeqs ON #Tmp_Candidate_MasterSeqs(Seq_ID_Local)
				
				Set @CurrentLocation = 'Create #Tmp_NewSeqIDs_for_UnkModPeptides'
				If @PreviewSql >= 1
					print @CurrentLocation
					
				CREATE TABLE #Tmp_NewSeqIDs_for_UnkModPeptides (
					Seq_ID_Local int NOT NULL,
					Seq_ID int NOT NULL
				)
			
				-- Add an index to #Tmp_NewSeqIDs_for_UnkModPeptides
				CREATE CLUSTERED INDEX #IX_Tmp_NewSeqIDs_for_UnkModPeptides ON #Tmp_NewSeqIDs_for_UnkModPeptides(Seq_ID_Local)
				
				
				-----------------------------------------------------------
				-- Rename unknown-named mods to have generic names
				-----------------------------------------------------------
				--
				Set @CurrentLocation = 'Populate #Tmp_ModDetails_for_SeqIDs_with_UnkMods'
				--
				Set @S = ''
				Set @S = @S + ' INSERT INTO #Tmp_ModDetails_for_SeqIDs_with_UnkMods (Seq_ID_Local, Mass_Correction_Tag, Position)'
				Set @S = @S + ' SELECT SC.Seq_ID_Local, '
				Set @S = @S +        ' CASE WHEN SCMD.Mass_Correction_Tag LIKE ''UnkMod[0-9][0-9]'' OR '
				Set @S = @S +                  ' SCMD.Mass_Correction_Tag LIKE ''Mod[0-9][0-9][0-9][0-9][0-9]'' OR '
				Set @S = @S +                  ' SCMD.Mass_Correction_Tag LIKE ''M[0-9][0-9][0-9][0-9][0-9][0-9][0-9]'' '
				Set @S = @S +                  ' THEN ''UnkMod00'' '
				Set @S = @S +             ' ELSE SCMD.Mass_Correction_Tag '
				Set @S = @S +        ' END AS Mass_Correction_Tag, '
				Set @S = @S +        ' SCMD.Position AS Position '
				Set @S = @S + ' FROM #Tmp_Peptides_with_UnkMods UnkModPeptides INNER JOIN '
				Set @S = @S +        @CandidatesSequencesTableName + ' SC ON UnkModPeptides.Seq_ID_Local = SC.Seq_ID_Local INNER JOIN '
				Set @S = @S +        @CandidateModDetailsTableName + ' SCMD ON SC.Seq_ID_Local = SCMD.Seq_ID_Local '
				
				If @CandidateTablesContainJobColumn <> 0
					Set @S = @S +   ' AND SC.Job = ' + @jobStr + ' AND SCMD.Job = ' + @jobStr
									
				If @PreviewSql >= 1
					Print @S
				If @PreviewSql <> 1
					Exec (@S)
		
				
				-----------------------------------------------------------
				-- Find existing peptides in T_Sequence that have
				--   the same clean sequence, a mass within 0.005 Da, the
				--   same number of mods, and mods at the same position
				-- When doing this, we rename the unknown-named mods to have generic names
				-----------------------------------------------------------
				--
				Set @CurrentLocation = 'Populate #Tmp_Candidate_MasterSeqs'
				--
				Set @S = ''
				Set @S = @S + ' INSERT INTO #Tmp_Candidate_MasterSeqs (Seq_ID_Local, Seq_ID, Mass_Correction_Tag, Position) '
				Set @S = @S + ' SELECT UnkModPeptides.Seq_ID_Local, '
				Set @S = @S +        ' S.Seq_ID, '
				Set @S = @S +        ' CASE WHEN MD.Mass_Correction_Tag LIKE ''UnkMod[0-9][0-9]'' OR '
				Set @S = @S +                  ' MD.Mass_Correction_Tag LIKE ''Mod[0-9][0-9][0-9][0-9][0-9]'' OR '
				Set @S = @S +                  ' MD.Mass_Correction_Tag LIKE ''M[0-9][0-9][0-9][0-9][0-9][0-9][0-9]'' '
				Set @S = @S +                  ' THEN ''UnkMod00'' '
				Set @S = @S +             ' ELSE MD.Mass_Correction_Tag '
				Set @S = @S +        ' END AS Mass_Correction_Tag, '
				Set @S = @S +        ' MD.Position AS Position '
				Set @S = @S + ' FROM #Tmp_Peptides_with_UnkMods UnkModPeptides '
				Set @S = @S +      ' INNER JOIN #Tmp_ModDetails_for_SeqIDs_with_UnkMods NewSeqsModDetails '
				Set @S = @S +         ' ON UnkModPeptides.Seq_ID_Local = NewSeqsModDetails.Seq_ID_Local '
				Set @S = @S +      ' INNER JOIN T_Sequence S '
				Set @S = @S +         ' ON ABS(S.Monoisotopic_Mass - UnkModPeptides.Monoisotopic_Mass) < 0.005 AND '
				Set @S = @S +            ' S.Clean_Sequence = UnkModPeptides.Clean_Sequence AND '
				Set @S = @S +            ' S.Mod_Count = UnkModPeptides.Mod_Count '
				Set @S = @S +      ' INNER JOIN T_Mod_Descriptors MD '
				Set @S = @S +         ' ON MD.Seq_ID = S.Seq_ID AND '
				Set @S = @S +         ' MD.Position = NewSeqsModDetails.Position '
						
				If @PreviewSql >= 1
					Print @S
				If @PreviewSql <> 1
					Exec (@S)
		
		
				-----------------------------------------------------------
				-- Now match up #Tmp_ModDetails_for_SeqIDs_with_UnkMods and #Tmp_Candidate_MasterSeqs
				-- We're looking for existing peptides with the same mods (or generically named mods) at the same positions
				-- If multiple matches exist, we choose the first one using MIN(MatchQ.Seq_ID)
				-----------------------------------------------------------
				--
				Set @CurrentLocation = 'Match up #Tmp_ModDetails_for_SeqIDs_with_UnkMods and #Tmp_Candidate_MasterSeqs'
				If @PreviewSql >= 1
					print @CurrentLocation

				Set @S = ''
				Set @S = @S + ' INSERT INTO #Tmp_NewSeqIDs_for_UnkModPeptides (Seq_ID_Local, Seq_ID) '
				Set @S = @S + ' SELECT MatchQ.Seq_ID_Local, '
				Set @S = @S +        ' MIN(MatchQ.Seq_ID) AS Best_Matching_Seq_ID '
				Set @S = @S + ' FROM ( SELECT CandidateSeqs.Seq_ID_Local, '
				Set @S = @S +               ' CandidateSeqs.Seq_ID, '
				Set @S = @S +               ' COUNT(*) AS Mod_Count '
				Set @S = @S +        ' FROM #Tmp_ModDetails_for_SeqIDs_with_UnkMods NewSeqsModDetails '
				Set @S = @S +             ' INNER JOIN #Tmp_Candidate_MasterSeqs CandidateSeqs '
				Set @S = @S +               ' ON NewSeqsModDetails.Seq_ID_Local = CandidateSeqs.Seq_ID_Local AND '
				Set @S = @S +                  ' NewSeqsModDetails.Mass_Correction_Tag = CandidateSeqs.Mass_Correction_Tag AND '
				Set @S = @S +                  ' NewSeqsModDetails.Position = CandidateSeqs.Position '
				Set @S = @S +        ' GROUP BY CandidateSeqs.Seq_ID_Local, CandidateSeqs.Seq_ID  '
				Set @S = @S +      ' ) MatchQ '
				Set @S = @S +      ' INNER JOIN #Tmp_Peptides_with_UnkMods UnkModPeptides '
				Set @S = @S +        ' ON MatchQ.Seq_ID_Local = UnkModPeptides.Seq_ID_Local AND '
				Set @S = @S +           ' MatchQ.Mod_Count = UnkModPeptides.Mod_Count '
				Set @S = @S + ' GROUP BY MatchQ.Seq_ID_Local '
		
				If @PreviewSql >= 1
					Print @S
				If @PreviewSql <> 1
					Exec (@S)
		
				If Exists (Select * from #Tmp_NewSeqIDs_for_UnkModPeptides) Or @PreviewSql >= 1
				Begin -- <c>
					-----------------------------------------------------------
					-- Store the matching Seq_ID values
					-----------------------------------------------------------
					--
					Set @CurrentLocation = 'Update Seq_ID in @CandidatesSequencesTableName using #Tmp_NewSeqIDs_for_UnkModPeptides'
					If @PreviewSql >= 1
						print @CurrentLocation
					
					Set @S = ''
					Set @S = @S + ' UPDATE ' + @CandidatesSequencesTableName
					Set @S = @S + ' Set Seq_ID = MSeqData.Seq_ID'
					Set @S = @S + ' FROM ' + @CandidatesSequencesTableName + ' SC '
					Set @S = @S +          ' INNER JOIN #Tmp_NewSeqIDs_for_UnkModPeptides MSeqData ON '
					Set @S = @S +            ' SC.Seq_ID_Local = MSeqData.Seq_ID_Local'
					If @CandidateTablesContainJobColumn <> 0
						Set @S = @S + ' WHERE SC.Job = ' + @jobStr
					
					If @PreviewSql >= 1
						Print @S
					If @PreviewSql <> 1
						Exec (@S)
					
					-----------------------------------------------------------
					-- Update the count of the number of entries with null Seq_ID Values
					-----------------------------------------------------------
					--		
					Set @CurrentLocation = 'Re-count the number of entries with null Seq_ID Values'
					If @PreviewSql >= 1
						print @CurrentLocation

					exec @myError = sp_executesql @SCountUnMatched, @ParamDefCountUnmatched, @MatchCount = @NewSequenceCountExpected output
					--
					If @myError <> 0
					Begin
						Set @message = 'Error counting Null Seq_ID values in ' + @CandidatesSequencesTableName + ' for job ' + @jobStr
						goto Done
					End
					
				End -- </c>
				
				If @PreviewSql >= 2
				Begin
					SELECT 'NewPeptides with UnkMods' AS Source, *
					FROM #Tmp_ModDetails_for_SeqIDs_with_UnkMods
					ORDER BY Seq_ID_Local, Position
					
					SELECT 'Candidate MasterSeqs' as Source, *
					FROM #Tmp_Candidate_MasterSeqs
					ORDER BY Seq_ID_Local, Seq_ID, Position
								
					Set @S = ''
					Set @S = @S + ' SELECT ''NewPeptides matching existing MasterSeqs'' as Source, SC.* '
					Set @S = @S + ' FROM ' + @CandidatesSequencesTableName + ' SC '
					Set @S = @S +          ' INNER JOIN #Tmp_NewSeqIDs_for_UnkModPeptides MSeqData ON '
					Set @S = @S +            ' SC.Seq_ID_Local = MSeqData.Seq_ID_Local'
					If @CandidateTablesContainJobColumn <> 0
						Set @S = @S + ' WHERE SC.Job = ' + @jobStr
					Set @S = @S + ' ORDER BY SC.Seq_ID_Local'

					Exec (@S)
						
				End
				
			End -- </b1>
			
		End -- </a1>
		*/
		
		If @NewSequenceCountExpected = 0
		Begin
			-- All of the peptides matched existing sequences
			--
			UPDATE T_Candidate_Seq_Processing_History
			SET Last_Affected = GetDate(), Sequence_Count_New = 0
			WHERE Entry_ID = @ProcessingHistoryEntryIDCurrent
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
		End
		Else
		Begin -- <a2>
		
			-----------------------------------------------------------
			-- Create a temporary table to hold the Seq_ID_Local values
			-- that will get new Seq_ID values assigned to them
			-----------------------------------------------------------

			Set @CurrentLocation = 'Create #T_Sequence_IDs_To_Update'
			If @PreviewSql >= 1
				print @CurrentLocation

			CREATE TABLE #T_Sequence_IDs_To_Update (
				Unique_ID int identity(1,1),
				Seq_ID_Local int NOT NULL
			)
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			If @myError <> 0
			Begin
				Set @message = 'Error creating temporary table #T_Sequence_IDs_To_Update'
				goto Done
			End
			
			-- Add an index to #T_Sequence_IDs_To_Update
			CREATE UNIQUE CLUSTERED INDEX #IX_T_Sequence_IDs_To_Update ON #T_Sequence_IDs_To_Update(Seq_ID_Local)
							
			-----------------------------------------------------------
			-- Populate #T_Sequence_IDs_To_Update
			-----------------------------------------------------------
			--
			Set @CurrentLocation = 'Populate #T_Sequence_IDs_To_Update'
			If @PreviewSql >= 1
				print @CurrentLocation
			
			Set @S = ''
			Set @S = @S + ' INSERT INTO #T_Sequence_IDs_To_Update (Seq_ID_Local)'
			Set @S = @S + ' SELECT SC.Seq_ID_Local'
			Set @S = @S + ' FROM ' + @CandidatesSequencesTableName + ' SC '
			Set @S = @S + ' WHERE SC.Seq_ID IS NULL'
			If @CandidateTablesContainJobColumn <> 0
				Set @S = @S +   ' AND SC.Job = ' + @jobStr
			--
			Exec (@S)
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			If @myError <> 0
			Begin
				Set @message = 'Error populating #T_Sequence_IDs_To_Update for job ' + @jobStr
				goto Done
			End
			Else
				Set @NewSequenceCountExpected = @myRowCount
			
			
			-----------------------------------------------------------
			-- Now assign Seq_ID values for the new sequences in @CandidatesSequencesTableName
			-- Since we're using transactions, do this in batches of @NewSequencesBatchSize sequences at a time
			-----------------------------------------------------------
			
			Set @NewSequenceCountAdded = 0
			Set @UniqueIDMin = 1
			Set @Continue = 1
			While @Continue = 1
			Begin -- <b2>
				-- Start another transaction
				Set @transName = 'AddNewSequencesFromCandidates'
				Begin Transaction @transName

				Set @SeqIDLocalFilter = 'SeqIDs.Unique_ID BETWEEN ' + Convert(varchar(19), @UniqueIDMin) + ' AND ' + Convert(varchar(19), @UniqueIDMin + @NewSequencesBatchSize - 1)
				
				Set @CurrentLocation = 'Insert new sequences into T_Sequence for ' + IsNull(@SeqIDLocalFilter, 'SeqIDs.Unique_ID BETWEEN ?? and ??')
				If @PreviewSql >= 1
					print @CurrentLocation
				
				Set @S = ''
				Set @S = @S + ' INSERT INTO T_Sequence (Clean_Sequence, Mod_Count, Mod_Description, Monoisotopic_Mass, Last_Affected)'
				Set @S = @S + ' SELECT Clean_Sequence, Mod_Count, Mod_Description, Monoisotopic_Mass, GETDATE() AS Last_Affected'
				Set @S = @S + ' FROM ' + @CandidatesSequencesTableName + ' SC INNER JOIN'
				Set @S = @S +        ' #T_Sequence_IDs_To_Update SeqIDs ON SC.Seq_ID_Local = SeqIDs.Seq_ID_Local '
				Set @S = @S + ' WHERE ' + @SeqIDLocalFilter
				If @CandidateTablesContainJobColumn <> 0
					Set @S = @S +   ' AND SC.Job = ' + @jobStr
				--
				If @PreviewSql >= 1
					Print @S
				If @PreviewSql = 0
					Exec (@S)
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
				--
				If @myError <> 0
				Begin
					rollback transaction @transName
					Set @message = 'Error inserting new sequences into the T_Sequence table in Master_Sequences for job ' + @jobStr
					goto Done
				End

				Set @NewSequenceCountAdded = @NewSequenceCountAdded + @myRowCount

				-----------------------------------------------------------
				-- Update the Seq_ID values for the new sequences just added
				-----------------------------------------------------------
				--
				Set @CurrentLocation = 'Assign the new Seq_ID values for ' + IsNull(@SeqIDLocalFilter, 'SeqIDs.Unique_ID BETWEEN ?? and ??')
				If @PreviewSql >= 1
					print @CurrentLocation
				
				Set @S = ''
				Set @S = @S + ' UPDATE ' + @CandidatesSequencesTableName
				Set @S = @S + ' Set Seq_ID = MSeqData.Seq_ID'
				Set @S = @S + ' FROM ' + @CandidatesSequencesTableName + ' SC INNER JOIN'
				Set @S = @S +      ' #T_Sequence_IDs_To_Update SeqIDs ON SC.Seq_ID_Local = SeqIDs.Seq_ID_Local INNER JOIN'
				Set @S = @S +      ' T_Sequence MSeqData ON '
				Set @S = @S +        ' SC.Clean_Sequence = MSeqData.Clean_Sequence AND '
				Set @S = @S +        ' SC.Mod_Count = MSeqData.Mod_Count AND '
				Set @S = @S +        ' SC.Mod_Description = MSeqData.Mod_Description'
				Set @S = @S + ' WHERE ' + @SeqIDLocalFilter
				If @CandidateTablesContainJobColumn <> 0
					Set @S = @S + ' AND SC.Job = ' + @jobStr
				--
				If @PreviewSql >= 1
					Print @S
				If @PreviewSql = 0
					Exec (@S)
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
				--
				If @myError <> 0
				Begin
					rollback transaction @transName
					Set @message = 'Error inserting new sequences into the T_Sequence table in Master_Sequences for job ' + @jobStr
					goto Done
				End
				
				-----------------------------------------------------------
				-- Lastly, populate T_Mod_Descriptors with the modification details for the new sequences
				-----------------------------------------------------------
				--
				Set @CurrentLocation = 'Populate T_Mod_Descriptors for ' + IsNull(@SeqIDLocalFilter, 'SeqIDs.Unique_ID BETWEEN ?? and ??')
				If @PreviewSql >= 1
					print @CurrentLocation
				
				Set @S = ''
				Set @S = @S + ' INSERT INTO T_Mod_Descriptors (Seq_ID, Mass_Correction_Tag, Position)'
				Set @S = @S + ' SELECT SC.Seq_ID, SCMD.Mass_Correction_Tag, SCMD.Position'
				Set @S = @S + ' FROM ' + @CandidatesSequencesTableName + ' SC INNER JOIN'
				Set @S = @S +      ' #T_Sequence_IDs_To_Update SeqIDs ON SC.Seq_ID_Local = SeqIDs.Seq_ID_Local INNER JOIN'
				Set @S = @S +      ' ' + @CandidateModDetailsTableName + ' SCMD ON '
				Set @S = @S +      ' SC.Seq_ID_Local = SCMD.Seq_ID_Local'
				If @CandidateTablesContainJobColumn <> 0
					Set @S = @S +  ' AND SC.Job = SCMD.Job'

				Set @S = @S + ' WHERE NOT SC.Seq_ID IS NULL AND ' + @SeqIDLocalFilter
				If @CandidateTablesContainJobColumn <> 0
					Set @S = @S +   ' AND SC.Job = ' + @jobStr
				--
				If @PreviewSql >= 1
					Print @S
				If @PreviewSql = 0
					Exec (@S)
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
				--
				If @myError <> 0
				Begin
					rollback transaction @transName
					Set @message = 'Error inserting new modification details into the T_Mod_Descriptors table in Master_Sequences for job ' + @jobStr
					goto Done
				End

				-----------------------------------------------
				-- Commit changes to T_Sequence, T_Mod_Descriptors, etc. If we made it this far
				-----------------------------------------------
				--
				Set @CurrentLocation = 'Commit changes'
				Commit Transaction @transName
				Set @transName = ''


				-----------------------------------------------
				-- Update T_Candidate_Seq_Processing_History
				-----------------------------------------------
				--
				UPDATE T_Candidate_Seq_Processing_History
				SET Last_Affected = GetDate(), Sequence_Count_New = @NewSequenceCountAdded
				WHERE Entry_ID = @ProcessingHistoryEntryIDCurrent
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
				
				
				-----------------------------------------------
				-- See If any sequences remain
				-----------------------------------------------
				--
				Set @UniqueIDMin = @UniqueIDMin + @NewSequencesBatchSize

				Set @myRowCount = 0
				SELECT @myRowCount = COUNT(*)
				FROM #T_Sequence_IDs_To_Update
				WHERE Unique_ID >= @UniqueIDMin
				
				If @myRowCount = 0
					Set @Continue = 0
			End -- </b2>

			If @PreviewSql = 0 AND @NewSequenceCountAdded <> @NewSequenceCountExpected
			Begin
				Set @message = 'Number of new sequences added to the T_Sequence table in Master_Sequences was not the expected value for job ' + @jobStr + ' (' + Convert(varchar(12), @NewSequenceCountAdded) + ' vs. ' + Convert(varchar(12), @NewSequenceCountExpected) + ')'
				Set @myError = 53000
				goto Done
			End

			-----------------------------------------------------------
			-- Make sure the number of modifications added to T_Mod_Descriptors
			-- for each sequence corresponds with the Mod_Count value in T_Sequence
			-----------------------------------------------------------
			--
			Set @CurrentLocation = 'Validate number of modifications added to T_Mod_Descriptors'
			If @PreviewSql >= 1
				print @CurrentLocation
			
			Set @S = ''
			Set @S = @S + ' SELECT @MismatchCount = COUNT(Seq_ID)'
			Set @S = @S + ' FROM (SELECT MSeqData.Seq_ID, MSeqData.Clean_Sequence, '
			Set @S = @S +              ' MSeqData.Mod_Count, COUNT(*) AS ModCountRows'
			Set @S = @S +       ' FROM ' + @CandidatesSequencesTableName + ' SC INNER JOIN'
			Set @S = @S +            ' #T_Sequence_IDs_To_Update SeqIDs ON SC.Seq_ID_Local = SeqIDs.Seq_ID_Local INNER JOIN '
				
			Set @S = @S +            ' T_Sequence MSeqData ON SC.Seq_ID = MSeqData.Seq_ID INNER JOIN'
			Set @S = @S +            ' T_Mod_Descriptors MD ON MSeqData.Seq_ID = MD.Seq_ID'
			Set @S = @S +       ' WHERE (MSeqData.Mod_Count > 0)'
			If @CandidateTablesContainJobColumn <> 0
				Set @S = @S +         ' AND SC.Job = ' + @jobStr
			Set @S = @S +       ' GROUP BY MSeqData.Seq_ID, MSeqData.Clean_Sequence, MSeqData.Mod_Count'
			Set @S = @S +       ') LookupQ'
			Set @S = @S + ' WHERE (Mod_Count <> ModCountRows)'

			Set @ParamDef = '@MismatchCount int output'
			Set @MismatchCount = 0

			If @PreviewSql >= 1
				Print @S
			Else
				exec @myError = sp_executesql @S, @ParamDef, @MismatchCount = @MismatchCount output


			If @MismatchCount > 0
			Begin
				Set @message = 'Found ' + Convert(varchar(12), @MismatchCount) + ' new sequences with disagreeing entries in T_Mod_Descriptors vs. T_Sequence.Mod_Count for job ' + @jobStr
				Set @myError = 53001

				Set @S = ''
				Set @S = @S + ' SELECT TOP 1 @messageAddnl = ''First match is '' + Clean_Sequence + '' with '' + Convert(varchar(9), Mod_Count) + '' mods'
				Set @S = @S +                                ' but '' + Convert(varchar(9), ModCountRows) + '' mod count rows'''
				Set @S = @S + ' FROM (SELECT MSeqData.Seq_ID, MSeqData.Clean_Sequence, '
				Set @S = @S +             ' MSeqData.Mod_Count, COUNT(*) AS ModCountRows'
				Set @S = @S +       ' FROM ' + @CandidatesSequencesTableName + ' SC INNER JOIN'
				Set @S = @S +            ' #T_Sequence_IDs_To_Update SeqIDs ON SC.Seq_ID_Local = SeqIDs.Seq_ID_Local INNER JOIN '
					
				Set @S = @S +            ' T_Sequence MSeqData ON SC.Seq_ID = MSeqData.Seq_ID INNER JOIN'
				Set @S = @S +            ' T_Mod_Descriptors MD ON MSeqData.Seq_ID = MD.Seq_ID'
				Set @S = @S +       ' WHERE (MSeqData.Mod_Count > 0)'
				If @CandidateTablesContainJobColumn <> 0
					Set @S = @S +         ' AND SC.Job = ' + @jobStr
				Set @S = @S +   ' GROUP BY MSeqData.Seq_ID, MSeqData.Clean_Sequence, MSeqData.Mod_Count'
				Set @S = @S +       ') LookupQ'
				Set @S = @S + ' WHERE (Mod_Count <> ModCountRows)'

				Set @ParamDef = '@messageAddnl varchar(256) output'
				Set @messageAddnl = ''

				exec sp_executesql @S, @ParamDef, @messageAddnl output
				
				If Len(IsNull(@messageAddnl, '')) > 0
					Set @message = @message + '; ' + @messageAddnl

				goto Done
			End

			-- Bump up @count by the number of new sequences added
			Set @count = @Count + @NewSequenceCountAdded

		End -- </a2>

		-----------------------------------------------------------
		-- Add entries to T_Seq_Map or T_Seq_to_Archived_Protein_Collection_File_Map 
		-- for the updated sequences
		-----------------------------------------------------------
		--
		Set @CurrentLocation = 'Call StoreSeqIDMapInfo'
		If @PreviewSql = 0
			Exec StoreSeqIDMapInfo @OrganismDBFileID, @ProteinCollectionFileID, @CandidatesSequencesTableName

		If @PreviewSql >= 2
		Begin
			Set @S = ''
			Set @S = @S + ' SELECT SC.* '
			Set @S = @S + ' FROM ' + @CandidatesSequencesTableName + ' SC '
			If @CandidateTablesContainJobColumn <> 0
				Set @S = @S + ' WHERE SC.Job = ' + @jobStr
			Set @S = @S + ' ORDER BY SC.Seq_ID_Local'
			
			Exec (@S)
		End

		-----------------------------------------------------------
		-- Set Queue_State to 3 in T_Candidate_Seq_Processing_History
		-----------------------------------------------------------
		--
		UPDATE T_Candidate_Seq_Processing_History
		SET Queue_State = 3, Last_Affected = GetDate(), 
			Processing_Complete = GetDate(), Status_Message = 'Processed ' + Convert(varchar(12), @count) + ' peptides'
		WHERE Entry_ID = @ProcessingHistoryEntryIDCurrent
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'ProcessCandidateSequences')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
								
		If Len(IsNull(@transName, '')) > 0
			rollback transaction @transName
		
		Goto Done
	End Catch

Done:

	If @myError <> 0
		exec PostLogEntry 'Error', @message, 'ProcessCandidateSequences'

	If Not @ProcessingHistoryEntryIDCurrent Is Null
	Begin
		-- Make sure the Queue_State is >= 3 in T_Candidate_Seq_Processing_History
		-- for @ProcessingHistoryEntryIDCurrent

		UPDATE T_Candidate_Seq_Processing_History
		SET Queue_State = 5, 
			Status_Message = CASE WHEN Len(IsNull(Status_Message, '')) > 0 
							 THEN Status_Message + '; ' 
							 ELSE '' 
							 END + 'Queue_State found to be less than 3; setting to 5'
		WHERE Entry_ID = @ProcessingHistoryEntryIDCurrent AND Queue_State < 3
	End
		
	Return @myError

GO
GRANT EXECUTE ON [dbo].[ProcessCandidateSequences] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ProcessCandidateSequences] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ProcessCandidateSequences] TO [MTS_DB_Lite] AS [dbo]
GO
