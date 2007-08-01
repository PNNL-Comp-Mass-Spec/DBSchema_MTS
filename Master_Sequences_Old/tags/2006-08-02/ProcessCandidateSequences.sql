SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ProcessCandidateSequences]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ProcessCandidateSequences]
GO

CREATE PROCEDURE dbo.ProcessCandidateSequences
/****************************************************
** 
**	Desc:
**		Processes the candidate sequences in the given table 
**		(typically located in the Master_Seq_Scratch DB).  Assigns
**		a Seq_ID value to each sequence using the sequence, Mod_Count, and
**		Mod_Description information to determine if the sequence is new
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
**    
*****************************************************/
(
	@OrganismDBFileID int=0,							-- Organism DB file ID; if @OrganismDBFileID is non-zero, then @ProteinCollectionFileID is ignored
	@ProteinCollectionFileID int=0,						-- Protein collection file ID
	@CandidatesSequencesTableName varchar(256),			-- Table with candidate peptide sequences, populates the Seq_ID column in this table
	@CandidateModDetailsTableName varchar(256),			-- Table with the modification details for each sequence
	@CandidateTablesContainJobColumn tinyint,			-- Set to 1 if the candidate tables contain a Job column and thus need to be filtered on @Job
	@Job int,
	@count int=0 output,								-- Number of peptides processed
	@message varchar(256) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @jobStr varchar(12)
	set @jobStr = cast(@job as varchar(12))

	declare @S nvarchar(2048)
	declare @ParamDef nvarchar(1024)

	Declare @NewSequenceCountExpected int
	Declare @NewSequenceCountAdded int
	Declare @MismatchCount int
	Declare @messageAddnl varchar(256)
	
	-----------------------------------------------------------
	-- Create a temporary table to hold the Seq_ID_Local values that
	-- have new Seq_ID values assigned to them
	-----------------------------------------------------------
	CREATE TABLE #T_Sequence_IDs_To_Update (
		Seq_ID_Local int NOT NULL
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Error creating temporary table #T_Sequence_IDs_To_Update'
		goto Done
	end
	
	-- Add an index to #T_Sequence_IDs_To_Update
	CREATE UNIQUE CLUSTERED INDEX #IX_T_Sequence_IDs_To_Update ON #T_Sequence_IDs_To_Update(Seq_ID_Local)

	-----------------------------------------------------------
	-- Clear the Seq_ID values in @CandidatesSequencesTableName
	-----------------------------------------------------------
	Set @S = ''
	Set @S = @S + ' UPDATE ' + @CandidatesSequencesTableName
	Set @S = @S + ' SET Seq_ID = NULL'
	Set @S = @S + ' FROM ' + @CandidatesSequencesTableName + ' SC'
	Set @S = @S + ' WHERE NOT SC.Seq_ID IS NULL'
	If @CandidateTablesContainJobColumn <> 0
		Set @S = @S +   ' AND SC.Job = ' + @jobStr
	--
	Exec (@S)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


	-----------------------------------------------------------
	-- Start a transaction
	-----------------------------------------------------------
	Declare @transName varchar(32)
	Set @transName = 'AddNewSequencesFromCandidates'
	Begin Transaction @transName

	-----------------------------------------------------------
	-- First update the Seq_ID values for the known sequences
	-----------------------------------------------------------
	--
	Set @S = ''
	Set @S = @S + ' UPDATE ' + @CandidatesSequencesTableName
	Set @S = @S + ' SET Seq_ID = MSeqData.Seq_ID'
	Set @S = @S + ' FROM ' + @CandidatesSequencesTableName + ' SC INNER JOIN'
	Set @S = @S +      ' dbo.T_Sequence MSeqData ON '
	Set @S = @S +      ' SC.Clean_Sequence = MSeqData.Clean_Sequence AND '
	Set @S = @S +      ' SC.Mod_Count = MSeqData.Mod_Count AND '
	Set @S = @S + ' SC.Mod_Description = MSeqData.Mod_Description'
	If @CandidateTablesContainJobColumn <> 0
		Set @S = @S + ' WHERE SC.Job = ' + @jobStr
	--
	Exec (@S)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Error assigning Seq_ID values to candidate sequences for job ' + @jobStr
		goto Done
	end
	
	SET @count = @myRowCount
	
	-----------------------------------------------------------
	-- Construct a list of the rows that will be added
	-----------------------------------------------------------
	
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
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Error populating #T_Sequence_IDs_To_Update for job ' + @jobStr
		goto Done
	end
	
	Set @NewSequenceCountExpected = @myRowCount
	
	
	If @NewSequenceCountExpected > 0
	Begin
		-----------------------------------------------------------
		-- Now assign Seq_ID values for the new sequences in @CandidatesSequencesTableName
		-----------------------------------------------------------

		Set @S = ''
		Set @S = @S + ' INSERT INTO T_Sequence (Clean_Sequence, Mod_Count, Mod_Description, Monoisotopic_Mass, Last_Affected)'
		Set @S = @S + ' SELECT Clean_Sequence, Mod_Count, Mod_Description, Monoisotopic_Mass, GETDATE() AS Last_Affected'
		Set @S = @S + ' FROM ' + @CandidatesSequencesTableName + ' SC '
		Set @S = @S + ' WHERE SC.Seq_ID IS NULL'
		If @CandidateTablesContainJobColumn <> 0
			Set @S = @S +   ' AND SC.Job = ' + @jobStr
		--
		Exec (@S)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @myError <> 0
		begin
			rollback transaction @transName
			set @message = 'Error inserting new sequences into the T_Sequence table in Master_Sequences for job ' + @jobStr
			goto Done
		end

		Set @NewSequenceCountAdded = @myRowCount
		--
		If @NewSequenceCountAdded <> @NewSequenceCountExpected
		begin
			rollback transaction @transName
			set @message = 'Number of new sequences added to the T_Sequence table in Master_Sequences was not the expected value for job ' + @jobStr + ' (' + Convert(varchar(12), @NewSequenceCountAdded) + ' vs. ' + Convert(varchar(12), @NewSequenceCountExpected) + ')'
			set @myError = 53000
			goto Done
		end
		
		
		-----------------------------------------------------------
		-- Update the Seq_ID values for the new sequences just added
		-----------------------------------------------------------

		Set @S = ''
		Set @S = @S + ' UPDATE ' + @CandidatesSequencesTableName
		Set @S = @S + ' SET Seq_ID = MSeqData.Seq_ID'
		Set @S = @S + ' FROM ' + @CandidatesSequencesTableName + ' SC INNER JOIN'
		Set @S = @S +      ' #T_Sequence_IDs_To_Update SeqIDs ON SC.Seq_ID_Local = SeqIDs.Seq_ID_Local INNER JOIN'
		Set @S = @S +      ' dbo.T_Sequence MSeqData ON '
		Set @S = @S +      ' SC.Clean_Sequence = MSeqData.Clean_Sequence AND '
		Set @S = @S +      ' SC.Mod_Count = MSeqData.Mod_Count AND '
		Set @S = @S +      ' SC.Mod_Description = MSeqData.Mod_Description'
		If @CandidateTablesContainJobColumn <> 0
			Set @S = @S + ' WHERE SC.Job = ' + @jobStr
		--
		Exec (@S)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @myError <> 0
		begin
			rollback transaction @transName
			set @message = 'Error inserting new sequences into the T_Sequence table in Master_Sequences for job ' + @jobStr
			goto Done
		end

		-----------------------------------------------------------
		-- Lastly, populate T_Mod_Descriptors with the modification details for the new sequences
		-----------------------------------------------------------
		Set @S = ''
		Set @S = @S + ' INSERT INTO T_Mod_Descriptors (Seq_ID, Mass_Correction_Tag, Position)'
		Set @S = @S + ' SELECT SC.Seq_ID, SCMD.Mass_Correction_Tag, SCMD.Position'
		Set @S = @S + ' FROM ' + @CandidatesSequencesTableName + ' SC INNER JOIN'
		Set @S = @S +      ' #T_Sequence_IDs_To_Update SeqIDs ON SC.Seq_ID_Local = SeqIDs.Seq_ID_Local INNER JOIN'
		Set @S = @S +      ' ' + @CandidateModDetailsTableName + ' SCMD ON '
		Set @S = @S +      ' SC.Seq_ID_Local = SCMD.Seq_ID_Local'
		If @CandidateTablesContainJobColumn <> 0
			Set @S = @S +  ' AND SC.Job = SCMD.Job'
		
		Set @S = @S + ' WHERE NOT SC.Seq_ID IS NULL'
		If @CandidateTablesContainJobColumn <> 0
			Set @S = @S +   ' AND SC.Job = ' + @jobStr
		--
		Exec (@S)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @myError <> 0
		begin
			rollback transaction @transName
			set @message = 'Error inserting new modification details into the T_Mod_Descriptors table in Master_Sequences for job ' + @jobStr
			goto Done
		end


		-----------------------------------------------------------
		-- Make sure the number of modifications added to T_Mod_Descriptors
		-- for each sequence corresponds with the Mod_Count value in T_Sequence
		-----------------------------------------------------------

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
		
		set @ParamDef = '@MismatchCount int output'
		set @MismatchCount = 0
		
		exec @myError = sp_executesql @S, @ParamDef, @MismatchCount = @MismatchCount output
		
		If @MismatchCount > 0
		Begin
			rollback transaction @transName
			
			set @message = 'Found ' + Convert(varchar(12), @MismatchCount) + ' new sequences with disagreeing entries in T_Mod_Descriptors vs. T_Sequence.Mod_Count for job ' + @jobStr
			set @myError = 53001

			Set @S = ''
			Set @S = @S + ' SELECT TOP 1 @messageAddnl = ''First match is '' + Clean_Sequence + '' with '' + Convert(varchar(9), Mod_Count) + '' mods'
			Set @S = @S +                                ' but '' + Convert(varchar(9), ModCountRows) + '' mod count rows'''
			Set @S = @S + ' FROM (SELECT MSeqData.Seq_ID, MSeqData.Clean_Sequence, '
			Set @S = @S +              ' MSeqData.Mod_Count, COUNT(*) AS ModCountRows'
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

			set @ParamDef = '@messageAddnl varchar(256) output'
			set @messageAddnl = ''

			exec sp_executesql @S, @ParamDef, @messageAddnl output
			
			If Len(IsNull(@messageAddnl, '')) > 0
				Set @message = @message + '; ' + @messageAddnl
		
			goto Done
		End
		
		-- Bump up @Count by the number of new sequences added
		Set @count = @count + @NewSequenceCountAdded
	End

	-----------------------------------------------
	-- Commit changes to T_Sequence, T_Mod_Descriptors, etc. if we made it this far
	-----------------------------------------------
	--
	Commit Transaction @transName


	-----------------------------------------------------------
	-- Add entries to T_Seq_Map or T_Seq_to_Archived_Protein_Collection_File_Map 
	-- for the updated sequences
	-----------------------------------------------------------
	--
	Exec StoreSeqIDMapInfo @OrganismDBFileID, @ProteinCollectionFileID, @CandidatesSequencesTableName

	
Done:
	Return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[ProcessCandidateSequences]  TO [DMS_SP_User]
GO

