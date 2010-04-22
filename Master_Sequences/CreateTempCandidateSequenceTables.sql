/****** Object:  StoredProcedure [dbo].[CreateTempCandidateSequenceTables] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.CreateTempCandidateSequenceTables
/****************************************************
** 
**	Desc:   Creates two new tables to hold candidate sequences to process
**
**	Auth:	mem
**	Date:	01/15/2006
**			06/21/2006 mem - Removed tri-column primary key from the Sequence Candidate Mod Details table and switched to simply indexing the Seq_ID_Local column
**    
*****************************************************/
(
	@CandidatesSequencesTableName varchar(256)='' output,	-- Table with candidate peptide sequences, populates the Seq_ID column in this table
	@CandidateModDetailsTableName varchar(256)='' output,	-- Table with the modification details for each sequence
	@message varchar(256) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	set @CandidatesSequencesTableName = ''
	set @CandidateModDetailsTableName  = ''
	set @message = ''

	declare @GUID varchar(64)
	declare @Sql varchar(1024)

	-----------------------------------------------------------
	-- Create two tables in the SeqTemp database to cache the data to update
	-----------------------------------------------------------
	--
	-- We're using a GUID unique-ifier to assure the tables don't exist in the database
	
	Set @GUID = Replace(Convert(varchar(64), NewID()), '-', '')
	Set @CandidatesSequencesTableName = 'Master_Seq_Scratch.dbo.[T_CandidateSeqWork_' + @GUID + ']'
	Set @CandidateModDetailsTableName  = 'Master_Seq_Scratch.dbo.[T_CandidateModsSeqWork_' + @GUID + ']'
	
	-----------------------------------------------------------
	-- Create the Sequence Candidates table
	-----------------------------------------------------------
	--
	set @Sql = ''
	set @Sql = @Sql + ' CREATE TABLE ' + @CandidatesSequencesTableName + ' ('
	set @Sql = @Sql +   ' Seq_ID_Local int NOT NULL ,'
	set @Sql = @Sql +   ' Clean_Sequence varchar(850) NOT NULL ,'
	set @Sql = @Sql +   ' Mod_Count smallint NOT NULL ,'
	set @Sql = @Sql +   ' Mod_Description varchar(2048) NOT NULL ,'
	set @Sql = @Sql +   ' Monoisotopic_Mass float NULL ,'
	set @Sql = @Sql +   ' Seq_ID int NULL '
	set @Sql = @Sql + ' )'
	--
	Exec (@Sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table ' + @CandidatesSequencesTableName
		goto Done
	end

	set @sql = 'ALTER TABLE ' + @CandidatesSequencesTableName + ' ADD CONSTRAINT [PK_CandidateSeqWork' + @GUID + '] PRIMARY KEY CLUSTERED (Seq_ID_Local)'
	Exec (@sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating primary key on ' + @CandidatesSequencesTableName
		goto Done
	end

	set @sql = 'CREATE INDEX [IX_CandidateSeqWork' + @GUID + '_CleanSequence] ON ' + @CandidatesSequencesTableName + '([Clean_Sequence])'
	Exec (@sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	set @sql = 'CREATE INDEX [IX_CandidateSeqWork' + @GUID + '_ModCount] ON ' + @CandidatesSequencesTableName + '([Mod_Count])'
	Exec (@sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


	-----------------------------------------------------------
	-- Create the Sequence Candidate Mod Details table
	-----------------------------------------------------------
	--
	set @Sql = ''
	set @Sql = @Sql + ' CREATE TABLE ' + @CandidateModDetailsTableName + ' ('
	set @Sql = @Sql + '   Seq_ID_Local int NOT NULL,'
	set @Sql = @Sql + '   Mass_Correction_Tag varchar(128) NOT NULL,'
	set @Sql = @Sql + '   [Position] smallint NOT NULL'
	set @Sql = @Sql + ' )'
	--
	Exec (@Sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table ' + @CandidateModDetailsTableName
		goto Done
	end

	-- Note: the Sequence Candidate Mod Details table does not have a primary key since a given sequence could have
	--  residues with the same mass correction tag occurring multiple times at the same position
	-- However, we will create an index to speed access to this data and assure it sorts properly
	set @sql = 'CREATE CLUSTERED INDEX [IX_CandidateModsSeqWork' + @GUID + '] ON ' + @CandidateModDetailsTableName + '(Seq_ID_Local)'
	Exec (@sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating primary key on ' + @CandidateModDetailsTableName
		goto Done
	end

Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[CreateTempCandidateSequenceTables] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CreateTempCandidateSequenceTables] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CreateTempCandidateSequenceTables] TO [MTS_DB_Lite] AS [dbo]
GO
