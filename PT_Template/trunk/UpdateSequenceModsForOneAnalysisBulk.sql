SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UpdateSequenceModsForOneAnalysisBulk]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[UpdateSequenceModsForOneAnalysisBulk]
GO


CREATE Procedure dbo.UpdateSequenceModsForOneAnalysisBulk
/****************************************************
** 
**		Desc: Sequentially examines all unprocessed entries in
**			  T_Peptides for given analysis job
**			  and examines their peptide sequence for modifications
**			  and updates them accordingly 
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth:	grk
**		Date:	11/01/2001
**				04/17/2004 mem - Switched from using a cursor to using a while loop
**				07/03/2004 mem - Added @NextProcessState parameter
**				07/21/2004 mem - Now calling SetProcessState
**				07/26/2004 grk - extensive modification to use master sequence database
**				08/07/2004 mem - Added @paramFileFound logic
**				08/23/2004 grk - changed to consolidated mod description parameters
**				08/24/2004 mem - Added use of @cleanSequence, @modCount, and @modDescription with GetIDFromRawSequence
**				08/27/2004 grk - added section to get organism DB file ID and pass to master sequence
**				08/29/2004 mem - Added code optimization step to avoid unnecessary calls to the Master_Sequences DB
**				09/03/2004 mem - Stopped using #TTempPeptides to track the Peptide_ID values that need to be processed due to slow behavior from the temporary DB
**				02/09/2005 mem - Switched to using temporary tables to hold the new sequences and Seq_ID values
**				02/10/2005 mem - Switched to copying the data to process into a transfer DB on the master sequences server, then using Master_Sequences.dbo.GetIDsForRawSequences to populate the tables
**				02/21/2005 mem - Switched Master_Sequences location from PrismDev to Albert
**				04/23/2005 mem - Now checking the error code returned by Master_Sequences.dbo.GetIDsForRawSequences
**				09/29/2005 mem - Now populating Cleavage_State_Max in T_Sequence
**				10/06/2005 mem - Updated the Cleavage_State_Max population query to effectively store the max cleavage state across all jobs in T_Sequence, not just the max cleavage state for the given job
**    
*****************************************************/
	@NextProcessState int = 30,
	@job int,
	@count int=0 output,
	@message varchar(512)='' output
As
	set nocount on
	
	declare @myError int
	set @myError = 0
	
	declare @myRowcount int
	set @myRowcount = 0
	
	set @message = ''

	declare @MasterSequencesServerName varchar(64)
	set @MasterSequencesServerName = 'Albert'
	
	declare @jobStr varchar(12)
	set @jobStr = cast(@job as varchar(12))
	
	declare @parameterFileName varchar(128)
	
	declare @organismDBName varchar(128)
	declare @orgDBFileID int
	
	declare @processCount int
	set @processCount = 0
	
	declare @sequencesAdded int
	set @sequencesAdded = 0

	declare @DeleteTempTables tinyint
	set @DeleteTempTables = 0
		
	declare @PeptideSequencesTableName varchar(256)
	declare @UniqueSequencesTableName varchar(256)
	
	declare @Sql varchar(1024)
	
	-----------------------------------------------------------
	-- Get Analysis job information
	-----------------------------------------------------------
	--
	-- get parameters from analysis table, 
	--
	set @parameterFileName = ''
	set @organismDBName = ''
	
	SELECT	@parameterFileName = Parameter_File_Name,
			@organismDBName = Organism_DB_Name
	FROM	T_Analysis_Description
	WHERE	Job = @job
	--
	select @myError = @@error, @myRowcount = @@rowcount
	--
	if @parameterFileName = ''
	begin
		set @message = 'Could not get analysis parameter file information for job ' + @jobStr
		set @myError = 51111
		goto Done
	end

	-----------------------------------------------------------
	-- get organism DB file ID
	-----------------------------------------------------------
	
	set @orgDBFileID = 0

	SELECT @orgDBFileID = ID
	FROM MT_Main.dbo.V_DMS_Organism_DB_File_Import
	WHERE (FileName = @organismDBName)
	--
	select @myError = @@error, @myRowcount = @@rowcount
	--
	if @orgDBFileID = 0
	begin
		set @message = 'Could not get organism DB file ID for job ' + @jobStr
		set @myError = 51112
		goto Done
	end


	-----------------------------------------------------------
	-- Create two tables on the master sequences server to cache the data to update
	-----------------------------------------------------------
	--
	-- Warning: Update @MasterSequencesServerName above if changing from Albert to another computer
	exec Albert.Master_Sequences.dbo.CreateTempSequenceTables @PeptideSequencesTableName output, @UniqueSequencesTableName output
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem calling CreateTempSequenceTables to create the temporary sequence tables for job ' + @jobStr
		goto Done
	end
	else
		set @DeleteTempTables = 1

	-----------------------------------------------------------
	-- Populate @PeptideSequencesTableName with the data to parse
	-----------------------------------------------------------
	--
	Set @Sql = ''
	Set @Sql = @Sql + ' INSERT INTO ' + @MasterSequencesServerName + '.' + @PeptideSequencesTableName + ' (Peptide_ID, Peptide)'
	Set @Sql = @Sql + ' SELECT Peptide_ID, Peptide'
	Set @Sql = @Sql + ' FROM T_Peptides'
	Set @Sql = @Sql + ' WHERE Analysis_ID = ' + @jobStr
	--
	Exec (@Sql)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem populating ' + @PeptideSequencesTableName + ' with the peptides to process for job ' + @jobStr
		goto Done
	end


	-----------------------------------------------------------
	-- Call GetIDsForRawSequences to process the data in the temporary sequence tables
	-----------------------------------------------------------
	--
	exec @myError = Albert.Master_Sequences.dbo.GetIDsForRawSequences @parameterFileName, @organismDBName, @orgDBFileID,
															 @PeptideSequencesTableName, @UniqueSequencesTableName, @processCount output, @message output
	--
	if @myError <> 0
	begin
		If Len(@message) = 0
			set @message = 'Error calling Master_Sequences.dbo.GetIDsForRawSequences for job ' + @jobStr + ': ' + convert(varchar(12), @myError)
		else
			set @message = 'Error calling Master_Sequences.dbo.GetIDsForRawSequences for job ' + @jobStr + ': ' + @message
			
		goto Done
	end

	-----------------------------------------------------------
	-- Add the new sequences to T_Sequence
	-----------------------------------------------------------
	--
	Set @Sql = ''
	Set @Sql = @Sql + ' INSERT INTO T_Sequence (Seq_ID, Clean_Sequence, Mod_Count, Mod_Description)'
	Set @Sql = @Sql + ' SELECT S.Seq_ID, S.Clean_Sequence, S.Mod_Count, S.Mod_Description'
	Set @Sql = @Sql + ' FROM ' + @MasterSequencesServerName + '.' + @UniqueSequencesTableName + ' AS S' 
	Set @Sql = @Sql + '    LEFT OUTER JOIN T_Sequence ON S.Seq_ID = T_Sequence.Seq_ID'
	Set @Sql = @Sql + ' WHERE T_Sequence.Seq_ID IS NULL'
	--
	Exec (@Sql)
	--
	SELECT @myError = @@error, @myRowcount = @@rowcount
	--
	Set @sequencesAdded = @myRowCount
	
	
	-----------------------------------------------------------
	-- Update T_Peptides
	-----------------------------------------------------------
	--
	Set @Sql = ''
	Set @Sql = @Sql + ' UPDATE T_Peptides'
	Set @Sql = @Sql + ' SET Seq_ID = P.Seq_ID'
	Set @Sql = @Sql + ' FROM ' + @MasterSequencesServerName + '.' + @PeptideSequencesTableName + ' AS P' 
	Set @Sql = @Sql + '    INNER JOIN T_Peptides ON T_Peptides.Peptide_ID = P.Peptide_ID'
	--
	Exec (@Sql)
	--
	SELECT @myError = @@error, @myRowcount = @@rowcount

	Set @processCount = @myRowCount


	-----------------------------------------------------------
	-- Update Cleavage_State_Max in T_Sequence for the peptides present in this job
	-----------------------------------------------------------
	--	
	UPDATE T_Sequence
	SET Cleavage_State_Max = LookupQ.Cleavage_State_Max
	FROM T_Sequence Seq INNER JOIN (
          SELECT Pep.Seq_ID, MAX(ISNULL(PPM.Cleavage_State, 0)) AS Cleavage_State_Max
		  FROM T_Peptides Pep INNER JOIN
			 T_Peptide_to_Protein_Map PPM ON 
			 Pep.Peptide_ID = PPM.Peptide_ID INNER JOIN
			 T_Sequence ON Pep.Seq_ID = T_Sequence.Seq_ID
		  WHERE Pep.Analysis_ID = @job
		  GROUP BY Pep.Seq_ID
		) LookupQ ON Seq.Seq_ID = LookupQ.Seq_ID
	WHERE LookupQ.Cleavage_State_Max > Seq.Cleavage_State_Max OR
		  Seq.Cleavage_State_Max IS NULL
	--
	SELECT @myRowcount = @@rowcount, @myError = @@error


	-----------------------------------------------------------
	-- Update state of analysis job
	-----------------------------------------------------------
	--
	Exec SetProcessState @job, @NextProcessState

	set @count = @processCount
	set @message = 'Peptide sequence mods updated for job ' + @jobStr + '; Sequences processed: ' + convert(varchar(11), @processCount) + '; New sequences added: ' + convert(varchar(11), @sequencesAdded)

Done:
	
	-----------------------------------------------------------
	-- Delete the temporary sequence tables, since no longer needed
	-----------------------------------------------------------
	--
	If @DeleteTempTables = 1
		exec Albert.Master_Sequences.dbo.DropTempSequenceTables @PeptideSequencesTableName, @UniqueSequencesTableName

	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

