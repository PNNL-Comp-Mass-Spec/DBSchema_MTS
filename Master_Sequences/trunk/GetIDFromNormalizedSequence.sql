SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetIDFromNormalizedSequence]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetIDFromNormalizedSequence]
GO

CREATE PROCEDURE dbo.GetIDFromNormalizedSequence
/****************************************************
** 
**	Desc:
**		Returns the unique sequence ID for the
**      given clean sequence and static and dynamic
**      mod descriptions.
** 
**      New entries are made as needed in the main sequence
**      table, the mod sets tables, and the mod set
**      members table.
** 
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	grk
**	Date:	07/24/2004
**			08/06/2004 mem - Added population of @seqID when adding a new sequence
**			08/22/2004 grk - modified to work with consolidated mod description
**			08/24/2004 mem - Updated population of T_Seq_Map to check for existing values
**			02/26/2005 mem - Now only updating T_Seq_Map if @mapID is > 0
**			07/01/2005 mem - Now updating column Last_Affected in T_Sequence
**			06/07/2006 mem - Added support for Protein Collection File IDs and removed input parameter @mapID
**    
*****************************************************/
(
	@cleanSequence varchar(1024),
	@modDescription varchar(2048) = 'Iso_N15 :0,Sam:0,PepTermN:0,ProTermC:0,IodoAcet:2,OxDy16_M:3,OxDy_Met:10,IodoAcet:20',
	@modCount int = 8,
	@OrganismDBFileID int=0,				-- Organism DB file ID; if @OrganismDBFileID is non-zero, then @ProteinCollectionFileID is ignored; adds SeqID and MapID to T_Seq_Map if non-zero and not yet present
	@ProteinCollectionFileID int=0,			-- Protein collection file ID; adds SeqID and MapID to T_Seq_Map if non-zero and not yet present
	@seqID int output,
	@message varchar(256) output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @message = ''
	set @seqID = 0
	
	declare @result int
	declare @matchCount int

	-----------------------------------------------------------
	-- Try to find existing sequence and mod patterns
	-----------------------------------------------------------

	SELECT @seqID = T_Sequence.Seq_ID
	FROM T_Sequence
	WHERE
	(Clean_Sequence = @cleanSequence) AND 
	(Mod_Count = @modCount) AND
	(Mod_Description = @modDescription) 
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error trying to look up existing sequence'
		goto Done
	end
	
	-- found it, we're done
	--
	if @seqID <> 0
	begin
		goto Done
	end

	---------------------------------------------------
	-- Start transaction
	---------------------------------------------------
	--
	declare @transName varchar(32)
	set @transName = 'GetIDFromNormalizedSequence'
	begin transaction @transName


	-----------------------------------------------------------
	-- Insert clean sequence into sequence table
	-----------------------------------------------------------

	INSERT INTO T_Sequence
	(
		Clean_Sequence, 
		Mod_Count, 
		Mod_Description,
		Last_Affected
	)
	VALUES
	(
		@cleanSequence,
		@modCount,
		@modDescription,
		GetDate()
	)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount, @seqID = Scope_Identity()
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Error trying to insert sequence entry'
		set @seqID = 0
		goto done
	end

	if @modDescription <> ''
	begin --<a>
		---------------------------------------------------
		-- create temporary table to hold mod set members
		---------------------------------------------------

		CREATE TABLE #TModDescriptors (
			[Seq_ID] [int] NULL,
			[Mass_Correction_Tag] [char] (8) NULL,
			[Position] [int] NULL 
		)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Error trying to create temporary table'
			goto Done
		end

		-----------------------------------------------------------
		-- unroll mod description into temporary table (#TModDescriptors)
		-----------------------------------------------------------
		--
		exec @result = UnrollModDescription
							@seqID,
							@modDescription,
							@message output
		--
		if @result <> 0
		begin
			rollback transaction @transName
			--DELETE FROM T_Sequence WHERE Seq_ID = @seqID
			goto done
		end

		-----------------------------------------------------------
		-- Insert mod descriptors into mod descriptor table
		-----------------------------------------------------------
		
		INSERT INTO T_Mod_Descriptors
			(Seq_ID, Mass_Correction_Tag, [Position])
		SELECT 
			Seq_ID, Mass_Correction_Tag, [Position]
		FROM #TModDescriptors
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			rollback transaction @transName
			--DELETE FROM T_Sequence WHERE Seq_ID = @seqID
			set @message = 'Error trying to insert mod set members from temporary table'
			goto done
		end
		--
		if @myRowCount <> @modCount
		begin
			rollback transaction @transName
			--DELETE FROM T_Mod_Descriptors WHERE Seq_ID = @seqID
			--DELETE FROM T_Sequence WHERE Seq_ID = @seqID
			set @message = 'Number of descriptors does not match mod count'
			set @myError = 99
			goto Done
		end
	end --<a>
	---------------------------------------------------
	-- commit transaction
	---------------------------------------------------
	commit transaction @transName

	-----------------------------------------------------------
	-- exit
	-----------------------------------------------------------
Done:

	-----------------------------------------------------------
	-- Add entries to T_Seq_Map or T_Seq_to_Archived_Protein_Collection_File_Map 
	-- for the updated sequences
	-----------------------------------------------------------
	--
	If @myError = 0
	Begin
		If IsNull(@OrganismDBFileID, 0) > 0
		Begin
			Set @matchCount = 0
			SELECT @matchCount = COUNT(*)
			FROM T_Seq_Map
			WHERE Seq_ID = @seqID AND Map_ID = @OrganismDBFileID 
			
			If @matchCount = 0
			Begin
				INSERT INTO T_Seq_Map (Seq_ID, Map_ID)
				VALUES (@seqID, @OrganismDBFileID)
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
			End
		End
		Else
		If IsNull(@ProteinCollectionFileID, 0) > 0
		Begin
			Set @matchCount = 0
			SELECT @matchCount = COUNT(*)
			FROM T_Seq_to_Archived_Protein_Collection_File_Map
			WHERE Seq_ID = @seqID AND [File_ID] = @ProteinCollectionFileID 
			
			If @matchCount = 0
			Begin
				INSERT INTO T_Seq_to_Archived_Protein_Collection_File_Map (Seq_ID, [File_ID])
				VALUES (@seqID, @ProteinCollectionFileID)
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
			End
		End
	End
	
	Return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetIDFromNormalizedSequence]  TO [DMS_SP_User]
GO

