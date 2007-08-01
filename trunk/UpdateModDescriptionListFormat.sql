/****** Object:  StoredProcedure [dbo].[UpdateModDescriptionListFormat] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.UpdateModDescriptionListFormat
/****************************************************
**
**	Desc: Looks for entries in T_Sequence that contain
**		  -1, -2, -3, or -4 in the text
**		  Changes the values to a 1 or Len(Clean_Sequence) 
**		  (as appropriate) and updates T_Sequence.Mod_Description
**
**		  Note that this procedure uses table T_Tmp_Seq_IDs_To_Update
**		  to do its work and if that table already exists, then
**		  it will not re-populate it
**
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	06/28/2006
**    
*****************************************************/
(
	@SeqIDStart int = 0,
	@SeqIDEnd int = 0,
	@MaxSequencesToProcess int = 1000,
	@message varchar(255) = '' output
)
AS
	Set NoCount On

	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	Declare @SeqIDCurrent int
	Declare @SeqIDPointer int
	Declare @Continue int
	
	Declare @UpdateCount int

	Declare @CleanSequence varchar(850)
	Declare @ModCount smallint
	Declare @ModCountCompare smallint
	Declare @ModDescriptionOld varchar(2048)

	Declare @ModDescriptionNew varchar(2048)
	Declare @SequenceLength int
	Declare @UpdateEnabled tinyint
	
	Set @message = ''

	Declare @UpdateModPosition varchar(24)
	Set @UpdateModPosition = 'UpdateModPosition'

	------------------------------------------------
	-- Validate the inputs
	------------------------------------------------
	--
	Set @SeqIDStart = IsNull(@SeqIDStart, 0)
	Set @SeqIDEnd = IsNull(@SeqIDEnd, 0)
	
	------------------------------------------------
	-- Look for table T_Tmp_Seq_IDs_To_Update
	-- Create and populate it if not present
	-- Validate the entries if it is present
	------------------------------------------------
	if not exists (select * from sys.tables where name = 'T_Tmp_Seq_IDs_To_Update')
	Begin
		-- Create T_Tmp_Seq_IDs_To_Update

		CREATE TABLE [dbo].[T_Tmp_Seq_IDs_To_Update] (
			[Seq_ID] [int] NOT NULL
		) 
		
		CREATE  UNIQUE  CLUSTERED  INDEX [IX_T_Tmp_Seq_IDs_To_Update] ON [dbo].[T_Tmp_Seq_IDs_To_Update]([Seq_ID])
		
		-- Populate T_Tmp_Seq_IDs_To_Update
		INSERT INTO T_Tmp_Seq_IDs_To_Update (Seq_ID)
		SELECT Seq_ID
		FROM T_Sequence
		WHERE Mod_Count > 0 AND Mod_Description like '%:-%'
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
	End
	

	If @SeqIDEnd = 0
		SELECT @SeqIDEnd = Max(Seq_ID)
		FROM T_Tmp_Seq_IDs_To_Update
	
	If @SeqIDStart > @SeqIDEnd
		Set @SeqIDEnd = @SeqIDStart


	------------------------------------------------
	-- Step through the sequences in T_Tmp_Seq_IDs_To_Update
	------------------------------------------------
	--
	Set @UpdateCount = 0
	Set @SeqIDCurrent = @SeqIDStart-1
	
	Set @Continue = 1
	While @Continue = 1
	Begin
		Set @SequenceLength = 0
		
		SELECT TOP 1 
				@SeqIDCurrent = S.Seq_ID,
				@SequenceLength = LEN(S.Clean_Sequence), 
				@CleanSequence = S.Clean_Sequence,
				@ModCount = S.Mod_Count,
				@ModDescriptionOld = S.Mod_Description
		FROM T_Tmp_Seq_IDs_To_Update SeqList INNER JOIN 
			 T_Sequence S ON SeqList.Seq_ID = S.Seq_ID
		WHERE SeqList.Seq_ID > @SeqIDCurrent AND S.Mod_Count > 0 AND S.Mod_Description Like '%:-[1-4]%'
		ORDER BY SeqList.Seq_ID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
		If @myRowCount < 1 Or @SeqIDCurrent > @SeqIDEnd
			Set @continue = 0
		Else
		Begin
			-- Validate that Seq_ID is in T_Mod_Descriptors
			--  and that the number of entries equals Mod_Count
			SELECT @ModCountCompare = COUNT(*)
			FROM T_Mod_Descriptors
			WHERE Seq_ID = @SeqIDCurrent 
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			If @ModCountCompare <> @ModCount
			Begin
				Set @Message = 'Mod_Count values conflict for Seq_ID ' + Convert(varchar(19), @SeqIDCurrent) + ': ' + Convert(varchar(6), @ModCount) + ' in T_Sequence vs. ' + Convert(varchar(6), @ModCountCompare) + ' in T_Mod_Descriptors'
				Goto Done
			End

			-- Start a transaction
			Begin Transaction @UpdateModPosition

			-- Generate the new Mod_Description string
			Set @ModDescriptionNew = ''
			SELECT @ModDescriptionNew = @ModDescriptionNew + RTRIM(Mass_Correction_Tag) + ':' + CONVERT(varchar(4), [Position]) + ','
			FROM T_Mod_Descriptors
			WHERE Seq_ID = @SeqIDCurrent
			ORDER BY [Position], Mass_Correction_Tag
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			If @myError <> 0
			Begin
				Set @Message = 'Error generating Mod_Description for Seq_ID ' + Convert(varchar(19), @SeqIDCurrent)
				Rollback Transaction @UpdateModPosition
				Goto Done
			End
			
			If @myRowCount = 0
			Begin
				Set @Message = 'Zero-length Mod_Description for Seq_ID ' + Convert(varchar(19), @SeqIDCurrent) + '; this is unexpected'
				Rollback Transaction @UpdateModPosition
				Goto Done
			End
			
			-- Remove the trailing comma from @ModDescriptionNew
			Set @ModDescriptionNew = Left(@ModDescriptionNew, Len(@ModDescriptionNew)-1)

			-- See if an entry in T_Sequence already exists with @CleanSequence and with @ModDescriptionNew
			Set @SeqIDPointer = 0
			SELECT TOP 1 @SeqIDPointer = Seq_ID
			FROM T_Sequence
			WHERE Clean_Sequence = @CleanSequence And 
				  Mod_Count = @ModCount And
				  Mod_Description = @ModDescriptionNew And
				  Seq_ID <> @SeqIDCurrent
			ORDER BY Seq_ID
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			If @myError <> 0
			Begin
				Set @Message = 'Error looking for duplicate entry of Seq_ID ' + Convert(varchar(19), @SeqIDCurrent) + ' in T_Sequence'
				Rollback Transaction @UpdateModPosition
				Goto Done
			End

			If @SeqIDPointer <> 0
			Begin
				-- Add the flag ' -- DupSeq' to the end of @ModDescriptionNew
				Set @ModDescriptionNew = @ModDescriptionNew + ' -- DupSeq'
			End

			-- Update T_Sequence for @SeqIDCurrent
			UPDATE T_Sequence
			Set Mod_Description = @ModDescriptionNew
			WHERE Seq_ID = @SeqIDCurrent
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			If @myError <> 0
			Begin
				Set @Message = 'Error updating Mod_Description to ' + @ModDescriptionNew + ' for Seq_ID ' + Convert(varchar(19), @SeqIDCurrent) + ' in T_Sequence'
				Rollback Transaction @UpdateModPosition
				Goto Done
			End
			
			-- Make an entry in T_Seq_Update_History for @SeqIDCurrent
			INSERT INTO T_Seq_Update_History (
						Seq_ID, Clean_Sequence, Mod_Count, 
						Mod_Description_Old, Mod_Description_New, Seq_ID_Pointer)
			VALUES (	@SeqIDCurrent, @CleanSequence, @ModCount, 
						@ModDescriptionOld, @ModDescriptionNew, @SeqIDPointer)
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			-- Finalize the transaction
			Commit Transaction @UpdateModPosition


			If @SeqIDPointer <> 0
			Begin
				-- Make sure T_Seq_Map contains mappings between @SeqIDPointer and the map values defined for @SeqIDCurrent
				INSERT INTO T_Seq_Map (Seq_ID, Map_ID)
				SELECT A.Seq_ID_New, A.Map_ID
				FROM (SELECT @SeqIDPointer AS Seq_ID_New, Map_ID
					  FROM T_Seq_Map
					  WHERE Seq_ID = @SeqIDCurrent
					  ) A LEFT OUTER JOIN
					 (SELECT Seq_ID, Map_ID
					  FROM T_Seq_Map
					  WHERE Seq_ID = @SeqIDPointer
					  ) B ON 
					  A.Map_ID = B.Map_ID AND A.Seq_ID_New = B.Seq_ID
				WHERE B.Seq_ID IS NULL
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				-- Make sure T_Seq_to_Archived_Protein_Collection_File_Map contains mappings between @SeqIDPointer and the map values defined for @SeqIDCurrent
				INSERT INTO T_Seq_to_Archived_Protein_Collection_File_Map (Seq_ID, [File_ID])
				SELECT A.Seq_ID_New, A.[File_ID]
				FROM (SELECT @SeqIDPointer AS Seq_ID_New, [File_ID]
					  FROM T_Seq_to_Archived_Protein_Collection_File_Map
					  WHERE Seq_ID = @SeqIDCurrent
					  ) A LEFT OUTER JOIN
					 (SELECT Seq_ID, [File_ID]
					  FROM T_Seq_to_Archived_Protein_Collection_File_Map
					  WHERE Seq_ID = @SeqIDPointer
					  ) B ON 
					  A.[File_ID] = B.[File_ID] AND A.Seq_ID_New = B.Seq_ID
				WHERE B.Seq_ID IS NULL
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

			End

			Set @UpdateCount = @UpdateCount + 1
			If @MaxSequencesToProcess > 0
			Begin
				If @UpdateCount >= @MaxSequencesToProcess
					Set @Continue = 0
			End
			
			If @UpdateCount % 500 = 0
			Begin
				Set @UpdateEnabled = 1

				exec VerifyUpdateEnabled @CallingFunctionDescription = 'UpdateModDescriptionListFormat', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
				If @UpdateEnabled <> 1
					Set @Continue = 0

			End
			
			If @SeqIDCurrent >= @SeqIDEnd
				Set @Continue = 0

		End
	End

	Set @message = 'Done processing T_Tmp_Seq_IDs_To_Update; Sequences Updated = ' + Convert(varchar(12), @UpdateCount)
		
Done:
	Select @message As TheMessage
	
	Return @myError


GO
