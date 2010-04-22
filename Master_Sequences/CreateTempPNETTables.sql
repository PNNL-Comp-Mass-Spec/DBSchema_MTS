/****** Object:  StoredProcedure [dbo].[CreateTempPNETTables] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateTempPNETTables]
/****************************************************
** 
**	Desc:	Creates a new table to hold PNET data for updating T_Sequence
**
**	Auth:	mem
**	Date:	05/16/2005
**    
*****************************************************/
(
	@PNetTableName varchar(256)='' output,			-- Table with the Seq_ID and PNET values
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
	-- Create a table in the Master_Seq_Scratch database to cache the data to update
	-----------------------------------------------------------
	--
	-- Define the name to the peptide sequences working table
	-- We're using a GUID unique-ifier to assure this table doesn't exist in the database
	
	Set @GUID = Replace(Convert(varchar(64), NewID()), '-', '')
	Set @PNetTableName = 'Master_Seq_Scratch.dbo.[T_PNETSeqWork_' + @GUID + ']'
	
	-----------------------------------------------------------
	-- Create the PNET data table
	-----------------------------------------------------------
	--
	Set @Sql = ''
	Set @Sql = @Sql + ' CREATE TABLE ' + @PNetTableName + ' ('
	Set @Sql = @Sql + '   Seq_ID int NOT NULL,'
	Set @Sql = @Sql + '   PNET real NULL'
	Set @Sql = @Sql + ' )'
	--
	Exec (@Sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		Set @message = 'Problem creating temporary table ' + @PNetTableName
		goto Done
	end

	Set @sql = 'ALTER TABLE ' + @PNetTableName + ' ADD CONSTRAINT [PK_PNETSeqWork' + @GUID + '] PRIMARY KEY NONCLUSTERED (Seq_ID)'
	Exec (@sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		Set @message = 'Problem creating primary key on ' + @PNetTableName
		goto Done
	end

Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[CreateTempPNETTables] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CreateTempPNETTables] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CreateTempPNETTables] TO [MTS_DB_Lite] AS [dbo]
GO
