SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[StoreSeqIDMapInfo]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[StoreSeqIDMapInfo]
GO

CREATE PROCEDURE dbo.StoreSeqIDMapInfo
/****************************************************
** 
**	Desc:
**		Examines the Seq_ID values in table @SequencesTableName
**		and adds mapping information to table T_Seq_Map if @OrganismDBFileID is non-zero
**		or table T_Seq_to_Archived_Protein_Collection_File_Map if @ProteinCollectionFileID is non-zero
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	06/07/2006
**    
*****************************************************/
(
	@OrganismDBFileID int,					-- Organism DB file ID; if @OrganismDBFileID is non-zero, then @ProteinCollectionFileID is ignored
	@ProteinCollectionFileID int,			-- Protein collection file ID
	@SequencesTableName varchar(256)		-- Table containing a column named Seq_ID that contains the sequence ID values to add to the appropriate mapping table		
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @TargetTableName nvarchar(128)
	Declare @MapField nvarchar(64)
	Declare @MapValue nvarchar(64)
	
	Declare @S nvarchar(2048)

	-----------------------------------------------------------
	-- Add entries to T_Seq_Map or T_Seq_to_Archived_Protein_Collection_File_Map 
	-- for the sequences in @SequencesTableName
	-----------------------------------------------------------
	
	Set @TargetTableName = ''
	If IsNull(@OrganismDBFileID, 0) > 0
	Begin
		Set @TargetTableName = 'T_Seq_Map'
		Set @MapField = 'Map_ID'
		Set @MapValue = Convert(nvarchar(30), @OrganismDBFileID)
	End
	Else
	If IsNull(@ProteinCollectionFileID, 0) > 0
	Begin
		Set @TargetTableName = 'T_Seq_to_Archived_Protein_Collection_File_Map'
		Set @MapField = '[File_ID]'
		Set @MapValue = Convert(nvarchar(30), @ProteinCollectionFileID)
	End
	
	If Len(@TargetTableName) > 0
	Begin
		set @S = ''		
		set @S = @S + ' INSERT INTO ' + @TargetTableName + ' (Seq_ID, ' + @MapField + ')'
		set @S = @S + ' SELECT Seq_ID, ' + @MapValue + ' AS [File_ID]'
		set @S = @S + ' FROM ' + @SequencesTableName
		set @S = @S + ' WHERE Seq_ID NOT IN'
		set @S = @S +     ' (SELECT Pep.Seq_ID'
		set @S = @S +      ' FROM ' + @TargetTableName + ' MapTable INNER JOIN '
		set @S = @S +        @SequencesTableName + ' AS Pep ON '
		set @S = @S +      ' MapTable.Seq_ID = Pep.Seq_ID'
		set @S = @S +      ' WHERE MapTable.' + @MapField + ' = ' + @MapValue
		set @S = @S +      ' GROUP BY Pep.Seq_ID)'
		set @S = @S + 'GROUP BY Seq_ID'
		--
		Exec (@S)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
	End
	
Done:
	Return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

