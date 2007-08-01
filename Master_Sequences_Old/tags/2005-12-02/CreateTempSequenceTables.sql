SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CreateTempSequenceTables]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[CreateTempSequenceTables]
GO

CREATE PROCEDURE dbo.CreateTempSequenceTables
/****************************************************
** 
**		Desc:  
**        Creates two new tables to hold sequence data to process
**
**		Auth:	mem
**		Date:	02/10/2005
**    
*****************************************************/
	@PeptideSequencesTableName varchar(256)='' output,			-- Table with peptide sequences to read, populates the Seq_ID column in this table
	@UniqueSequencesTableName varchar(256)='' output,			-- Table to store the unique sequence information
	@message varchar(256) = '' output
As
	set nocount on
	
	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0

	declare @GUID varchar(64)
	declare @Sql varchar(1024)

	-----------------------------------------------------------
	-- Create two tables in the SeqTemp database to cache the data to update
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
	set @Sql = ''
	set @Sql = @Sql + ' CREATE TABLE ' + @PeptideSequencesTableName + ' ('
	set @Sql = @Sql + '   Peptide_ID int NOT NULL,'
	set @Sql = @Sql + '   Peptide varchar(850) NULL,'
	set @Sql = @Sql + '   Seq_ID int NULL'
	set @Sql = @Sql + ' )'
	--
	Exec (@Sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table ' + @PeptideSequencesTableName
		goto Done
	end

	set @sql = 'ALTER TABLE ' + @PeptideSequencesTableName + ' ADD CONSTRAINT [PK_PepSeqWork' + @GUID + '] PRIMARY KEY NONCLUSTERED (Peptide_ID)'
	Exec (@sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating primary key on ' + @PeptideSequencesTableName
		goto Done
	end


	-----------------------------------------------------------
	-- Create the Unique Sequences table
	-----------------------------------------------------------
	--
	set @Sql = ''
	set @Sql = @Sql + ' CREATE TABLE ' + @UniqueSequencesTableName + ' ('
	set @Sql = @Sql + '   Seq_ID int NOT NULL,'
	set @Sql = @Sql + '   Clean_Sequence varchar(850) NOT NULL,'
	set @Sql = @Sql + '   Mod_Count int NULL,'
	set @Sql = @Sql + '   Mod_Description varchar(2048) NULL'
	set @Sql = @Sql + ' )'
	--
	Exec (@Sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table ' + @UniqueSequencesTableName
		goto Done
	end

	set @sql = 'ALTER TABLE ' + @UniqueSequencesTableName + ' ADD CONSTRAINT [PK_UniqueSeqWork' + @GUID + '] PRIMARY KEY NONCLUSTERED (Seq_ID)'
	Exec (@sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating primary key on ' + @UniqueSequencesTableName
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

