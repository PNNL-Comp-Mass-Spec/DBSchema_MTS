SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CreateTempSequenceTables]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[CreateTempSequenceTables]
GO

CREATE PROCEDURE [dbo].[CreateTempSequenceTables]
/****************************************************
** 
**	Desc:	Creates two new tables to hold sequence data to process
**
**	Auth:	mem
**	Date:	02/10/2005
**			05/13/2006 mem - Updated comment to mention the Master_Seq_Scratch DB
**    
*****************************************************/
(
	@PeptideSequencesTableName varchar(256)='' output,			-- Table with peptide sequences to read, populates the Seq_ID column in this table
	@UniqueSequencesTableName varchar(256)='' output,			-- Table to store the unique sequence information
	@message varchar(256) = '' output
)
As
	Set nocount on
	
	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	Declare @GUID varchar(64)
	Declare @Sql varchar(1024)

	-----------------------------------------------------------
	-- Create two tables in the Master_Seq_Scratch database to cache the data to update
	-----------------------------------------------------------
	--
	-- Define the name to the peptide sequences working table
	-- We're using a GUID unique-ifier to assure this table doesn't exist in the database
	
	Set @GUID = Replace(Convert(varchar(64), NewID()), '-', '')
	Set @PeptideSequencesTableName = 'Master_Seq_Scratch.dbo.[T_PepSeqWork_' + @GUID + ']'
	Set @UniqueSequencesTableName  = 'Master_Seq_Scratch.dbo.[T_UniqueSeqWork_' + @GUID + ']'
	
	-----------------------------------------------------------
	-- Create the Peptide Sequences table
	-----------------------------------------------------------
	--
	Set @Sql = ''
	Set @Sql = @Sql + ' CREATE TABLE ' + @PeptideSequencesTableName + ' ('
	Set @Sql = @Sql + '   Peptide_ID int NOT NULL,'
	Set @Sql = @Sql + '   Peptide varchar(850) NULL,'
	Set @Sql = @Sql + '   Seq_ID int NULL'
	Set @Sql = @Sql + ' )'
	--
	Exec (@Sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		Set @message = 'Problem creating temporary table ' + @PeptideSequencesTableName
		goto Done
	end

	Set @sql = 'ALTER TABLE ' + @PeptideSequencesTableName + ' ADD CONSTRAINT [PK_PepSeqWork' + @GUID + '] PRIMARY KEY NONCLUSTERED (Peptide_ID)'
	Exec (@sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		Set @message = 'Problem creating primary key on ' + @PeptideSequencesTableName
		goto Done
	end


	-----------------------------------------------------------
	-- Create the Unique Sequences table
	-----------------------------------------------------------
	--
	Set @Sql = ''
	Set @Sql = @Sql + ' CREATE TABLE ' + @UniqueSequencesTableName + ' ('
	Set @Sql = @Sql + '   Seq_ID int NOT NULL,'
	Set @Sql = @Sql + '   Clean_Sequence varchar(850) NOT NULL,'
	Set @Sql = @Sql + '   Mod_Count int NULL,'
	Set @Sql = @Sql + '   Mod_Description varchar(2048) NULL'
	Set @Sql = @Sql + ' )'
	--
	Exec (@Sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		Set @message = 'Problem creating temporary table ' + @UniqueSequencesTableName
		goto Done
	end

	Set @sql = 'ALTER TABLE ' + @UniqueSequencesTableName + ' ADD CONSTRAINT [PK_UniqueSeqWork' + @GUID + '] PRIMARY KEY NONCLUSTERED (Seq_ID)'
	Exec (@sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		Set @message = 'Problem creating primary key on ' + @UniqueSequencesTableName
		goto Done
	end

Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[CreateTempSequenceTables]  TO [DMS_SP_User]
GO

