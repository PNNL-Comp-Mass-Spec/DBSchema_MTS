/****** Object:  StoredProcedure [dbo].[StoreSeqIDMapInfo] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
**			01/10/2008 mem - Now using a temporary table to determine the Seq_ID values that do not need to be added to T_Seq_Map or T_Seq_to_Archived_Protein_Collection_File_Map
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
	Declare @AddSeqIDTrans varchar(32)
	Set @AddSeqIDTrans = 'AddSeqID'
	
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
		CREATE TABLE #Tmp_Seq_ID_Ignore_List (
			Seq_ID int NOT NULL
		)
		
		Begin Transaction @AddSeqIDTrans
		
		set @S = ''
		set @S = @S + ' INSERT INTO #Tmp_Seq_ID_Ignore_List (Seq_ID) '
		set @S = @S + ' SELECT Pep.Seq_ID'
		set @S = @S + ' FROM ' + @TargetTableName + ' MapTable INNER JOIN '
		set @S = @S +        @SequencesTableName + ' AS Pep ON '
		set @S = @S +        ' MapTable.Seq_ID = Pep.Seq_ID'
		set @S = @S + ' WHERE MapTable.' + @MapField + ' = ' + @MapValue
		set @S = @S + ' GROUP BY Pep.Seq_ID'
		--
		Exec sp_executesql @S
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
		set @S = ''		
		set @S = @S + ' INSERT INTO ' + @TargetTableName + ' (Seq_ID, ' + @MapField + ')'
		set @S = @S + ' SELECT Seq_ID, ' + @MapValue + ' AS [File_ID]'
		set @S = @S + ' FROM ' + @SequencesTableName
		set @S = @S + ' WHERE Seq_ID NOT IN (SELECT Seq_ID FROM #Tmp_Seq_ID_Ignore_List)'
		set @S = @S + ' GROUP BY Seq_ID'
		--
		Exec sp_executesql @S
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
		Commit Transaction @AddSeqIDTrans
	End
	
Done:
	Return @myError

GO
