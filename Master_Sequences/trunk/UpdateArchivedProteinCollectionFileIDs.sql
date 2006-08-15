/****** Object:  StoredProcedure [dbo].[UpdateArchivedProteinCollectionFileIDs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.UpdateArchivedProteinCollectionFileIDs
/****************************************************
**
**	Desc:	Steps through the entries in T_Tmp_File_ID_Updates 
**			and updates T_Seq_to_Archived_Protein_Collection_File_Map as needed
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	07/04/2006
**    
*****************************************************/
(
	@message varchar(255) = '' output
)
AS
	Set NoCount On

	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	Declare @NewFileIDCurrent int
	Declare @Continue tinyint
	
	SELECT @NewFileIDCurrent = MIN(New_File_ID)-1
	FROM T_Tmp_File_ID_Updates
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	
	If @myRowCount = 0 Or @NewFileIDCurrent Is Null
	Begin
		set @message = 'Nothing to do'
		goto Done
	End

	-- Create a temporary table to hold the sequences to process
	CREATE TABLE #TmpSeqIDsToUpdate (
		[Seq_ID] [int] NOT NULL,
		AddSequence tinyint NOT NULL default(1)
	)

	CREATE CLUSTERED INDEX #IX_TmpSeqIDsToUpdate ON #TmpSeqIDsToUpdate ([Seq_ID])
	
	Set @Continue = 1
	While @Continue = 1
	Begin
		SELECT TOP 1 @NewFileIDCurrent = New_File_ID
		FROM T_Tmp_File_ID_Updates
		WHERE New_File_ID > @NewFileIDCurrent
		ORDER BY New_File_ID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
		If @myRowCount < 1 or @myError <> 0
			Set @continue = 0
		Else
		Begin
			-- Populate a temporary table with the Seq_ID values
			-- that should be mapped to @NewFileIDCurrent
			
			TRUNCATE TABLE #TmpSeqIDsToUpdate
			
			INSERT INTO #TmpSeqIDsToUpdate (Seq_ID)
			SELECT DISTINCT Seq_ID
			FROM T_Seq_to_Archived_Protein_Collection_File_Map PCFM INNER JOIN
				T_Tmp_File_ID_Updates U ON 
				PCFM.[File_ID] = U.Old_File_ID
			WHERE U.New_File_ID = @NewFileIDCurrent
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			If @myError <> 0
			Begin
				Set @message = 'Error Populating #TmpSeqIDsToUpdate for New_File_ID ' + Convert(varchar(9), @NewFileIDCurrent)
				Goto Done
			End
			
			If @myRowCount > 0
			Begin
				Set @message = 'Found ' + Convert(varchar(12), @myRowCount) + ' Seq_ID values that should now be mapped to ' + Convert(varchar(9), @NewFileIDCurrent) + ' in T_Seq_to_Archived_Protein_Collection_File_Map'
				execute PostLogEntry 'Progress', @message, 'UpdateArchivedProteinCollectionFileIDs'
				Set @message = ''

				--Flag sequences that already exist in T_Seq_to_Archived_Protein_Collection_File_Map
				UPDATE #TmpSeqIDsToUpdate
				SET AddSequence = 0
				FROM T_Seq_to_Archived_Protein_Collection_File_Map PCFM INNER JOIN
					 #TmpSeqIDsToUpdate SIU ON PCFM.Seq_ID = SIU.Seq_ID AND PCFM.[File_ID] = @NewFileIDCurrent
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				If @myError <> 0
				Begin
					Set @message = 'Error Updating #TmpSeqIDsToUpdate.AddSequence for New_File_ID ' + Convert(varchar(9), @NewFileIDCurrent)
					Goto Done
				End

				Set @message = 'Found ' + Convert(varchar(12), @myRowCount) + ' Seq_ID values that are already mapped to ' + Convert(varchar(9), @NewFileIDCurrent) + ' in T_Seq_to_Archived_Protein_Collection_File_Map'
				execute PostLogEntry 'Progress', @message, 'UpdateArchivedProteinCollectionFileIDs'
				Set @message = ''
				
				-- Insert new entries into T_Seq_to_Archived_Protein_Collection_File_Map
				INSERT INTO T_Seq_to_Archived_Protein_Collection_File_Map (Seq_ID, [File_ID])
				SELECT Seq_ID, @NewFileIDCurrent
				FROM #TmpSeqIDsToUpdate
				WHERE AddSequence = 1
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				If @myError <> 0
				Begin
					Set @message = 'Error inserting new entries into T_Seq_to_Archived_Protein_Collection_File_Map for New_File_ID ' + Convert(varchar(9), @NewFileIDCurrent)
					Goto Done
				End
				
				Set @message = 'Added ' + Convert(varchar(12), @myRowCount) + ' rows to T_Seq_to_Archived_Protein_Collection_File_Map mapping Seq_Id to ' + Convert(varchar(9), @NewFileIDCurrent)
				execute PostLogEntry 'Progress', @message, 'UpdateArchivedProteinCollectionFileIDs'
				Set @message = ''

				-- Delete old entries in T_Seq_to_Archived_Protein_Collection_File_Map
				DELETE T_Seq_to_Archived_Protein_Collection_File_Map
				FROM T_Seq_to_Archived_Protein_Collection_File_Map PCFM INNER JOIN
					 T_Tmp_File_ID_Updates U ON 
					 PCFM.[File_ID] = U.Old_File_ID
				WHERE U.New_File_ID = @NewFileIDCurrent
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				If @myError <> 0
				Begin
					Set @message = 'Error deleting old entries from T_Seq_to_Archived_Protein_Collection_File_Map for old File_IDs corresponding to New_File_ID ' + Convert(varchar(9), @NewFileIDCurrent)
					Goto Done
				End

				Set @message = 'Deleted ' + Convert(varchar(12), @myRowCount) + ' old Seq_ID to File_ID mapping rows since now be mapped to ' + Convert(varchar(9), @NewFileIDCurrent)
				execute PostLogEntry 'Progress', @message, 'UpdateArchivedProteinCollectionFileIDs'
				Set @message = ''
				
			End

		End
	End

	Set @message = 'Done updating Seq_ID to File_ID mappings'
		
Done:
	Select @message As TheMessage
	
	Return @myError

GO
