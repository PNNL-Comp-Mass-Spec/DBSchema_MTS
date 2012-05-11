/****** Object:  StoredProcedure [dbo].[UpdateSequenceModsForOneAnalysisBulk] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure UpdateSequenceModsForOneAnalysisBulk
/****************************************************
** 
**	Desc: Sequentially examines all unprocessed entries in
**			  T_Peptides for given analysis job
**			  and examines their peptide sequence for modifications
**			  and updates them accordingly 
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	grk
**	Date:	11/01/2001
**			04/17/2004 mem - Switched from using a cursor to using a while loop
**			07/03/2004 mem - Added @NextProcessState parameter
**			07/21/2004 mem - Now calling SetProcessState
**			07/26/2004 grk - extensive modification to use master sequence database
**			08/07/2004 mem - Added @paramFileFound logic
**			08/23/2004 grk - changed to consolidated mod description parameters
**			08/24/2004 mem - Added use of @cleanSequence, @modCount, and @modDescription with GetIDFromRawSequence
**			08/27/2004 grk - added section to get organism DB file ID and pass to master sequence
**			08/29/2004 mem - Added code optimization step to avoid unnecessary calls to the Master_Sequences DB
**			09/03/2004 mem - Stopped using #TTempPeptides to track the Peptide_ID values that need to be processed due to slow behavior from the temporary DB
**			02/09/2005 mem - Switched to using temporary tables to hold the new sequences and Seq_ID values
**			02/10/2005 mem - Switched to copying the data to process into a transfer DB on the master sequences server, then using Master_Sequences.dbo.GetIDsForRawSequences to populate the tables
**			02/21/2005 mem - Switched Master_Sequences location from PrismDev to Albert
**			04/23/2005 mem - Now checking the error code returned by Master_Sequences.dbo.GetIDsForRawSequences
**			09/29/2005 mem - Now populating Cleavage_State_Max in T_Sequence
**			10/06/2005 mem - Updated the Cleavage_State_Max population query to effectively store the max cleavage state across all jobs in T_Sequence, not just the max cleavage state for the given job
**			01/18/2006 mem - Added logging statements when @logLevel >= 1
**			05/03/2006 mem - Switched Master_Sequences location from Albert to Daffy
**			06/08/2006 mem - Now using GetOrganismDBFileInfo to lookup the OrganismDBFileID or ProteinCollectionFileID value for the given job
**			11/21/2006 mem - Switched Master_Sequences location from Daffy to ProteinSeqs
**			11/27/2006 mem - Added support for option SkipPeptidesFromReversedProteins
**			11/30/2006 mem - Implemented Try...Catch error handling
**			07/23/2008 mem - Switched Master_Sequences location to Porky
**			08/20/2008 mem - Now checking for jobs where all of the loaded peptides have State_ID = 2
**			01/30/2010 mem - Added parameters @infoOnly, @MaxRowsToProcess, @OnlyProcessNullSeqIDRows, and @SkipDeleteTempTables
**			02/25/2010 mem - Switched Master_Sequences location to ProteinSeqs2
**			01/06/2012 mem - Updated to use T_Peptides.Job
**    
*****************************************************/
(
	@NextProcessState int = 30,
	@job int,
	@count int=0 output,
	@message varchar(512)='' output,
	@infoOnly tinyint = 0,
	@MaxRowsToProcess int = 0,
	@OnlyProcessNullSeqIDRows tinyint = 0,
	@SkipDeleteTempTables tinyint = 0
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'
	
	set @count = 0	
	set @message = ''
	set @MaxRowsToProcess = IsNull(@MaxRowsToProcess, 0)
	Set @OnlyProcessNullSeqIDRows = IsNull(@OnlyProcessNullSeqIDRows, 0)
	Set @SkipDeleteTempTables = IsNull(@SkipDeleteTempTables, 0)

	declare @MasterSequencesServerName varchar(64)
	set @MasterSequencesServerName = 'ProteinSeqs2'
	
	declare @jobStr varchar(12)
	set @jobStr = cast(@job as varchar(12))
	
	declare @parameterFileName varchar(128)
	declare @OrganismDBFileID int
	declare @ProteinCollectionFileID int

	declare @DeleteTempTables tinyint
	declare @processCount int
	declare @sequencesAdded int
	declare @SkipPeptidesFromReversedProteins tinyint
	
	set @DeleteTempTables = 0
	set @processCount = 0
	set @sequencesAdded = 0
		
	declare @PeptideSequencesTableName varchar(256)
	declare @UniqueSequencesTableName varchar(256)
	
	declare @Sql varchar(1024)
	
	declare @logLevel int
	set @logLevel = 1		-- Default to normal logging
	
	Begin Try
		Set @CurrentLocation = 'Lookup settings in T_Process_Step_Control and T_Analysis_Description'
		
		--------------------------------------------------------------
		-- Lookup the LogLevel state
		-- 0=Off, 1=Normal, 2=Verbose, 3=Debug
		--------------------------------------------------------------
		--
		SELECT @logLevel = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'LogLevel')

		--------------------------------------------------------------
		-- Lookup the value of SkipPeptidesFromReversedProteins in T_Process_Step_Control
		-- Assume skipping is enabled if the value is not present
		--------------------------------------------------------------
		--
		SELECT @SkipPeptidesFromReversedProteins = Enabled
		FROM T_Process_Step_Control
		WHERE Processing_Step_Name = 'SkipPeptidesFromReversedProteins'
		--
		SELECT @myRowcount = @@rowcount, @myError = @@error
		
		Set @SkipPeptidesFromReversedProteins = IsNull(@SkipPeptidesFromReversedProteins, 1)
		
		-----------------------------------------------------------
		-- Get Analysis job information
		-----------------------------------------------------------
		--
		-- get parameters from analysis table, 
		--
		set @parameterFileName = ''
		
		SELECT	@parameterFileName = Parameter_File_Name
		FROM	T_Analysis_Description
		WHERE	Job = @job
		--
		SELECT @myRowcount = @@rowcount, @myError = @@error
		--
		if @parameterFileName = ''
		begin
			set @message = 'Could not get analysis parameter file information for job ' + @jobStr
			set @myError = 51111
			goto Done
		end

		------------------------------------------------------------------
		-- Lookup the number of proteins and residues in Organism DB file (aka the FASTA file)
		--  or Protein Collection used for this analysis job
		-- Note that GetOrganismDBFileInfo will post an error to the log if the job
		--  has an unknown Fasta file or Protein Collection List
		------------------------------------------------------------------
		--
		Set @CurrentLocation = 'Call GetOrganismDBFileInfo for job ' + @jobStr
		
		Exec  @myError = GetOrganismDBFileInfo @job, 
								@OrganismDBFileID  = @OrganismDBFileID OUTPUT,
								@ProteinCollectionFileID = @ProteinCollectionFileID OUTPUT
		
		If @myError <> 0
		Begin
			-- GetOrganismDBFileInfo returned an error: abort processing 
			-- Note that UpdateSequenceModsForAvailableAnalyses looks for the text "Error calling GetOrganismDBFileInfo"
			-- If found, it will not re-post an error to the log
			Set @myError = 51112
			Set @message = 'Error calling GetOrganismDBFileInfo (Code ' + Convert(varchar(12), @myError) + ')'
			Goto Done
		End

		Set @OrganismDBFileID = IsNull(@OrganismDBFileID, 0)
		Set @ProteinCollectionFileID = IsNull(@ProteinCollectionFileID, 0)

		-----------------------------------------------------------
		-- Create two tables on the master sequences server to cache the data to update
		-----------------------------------------------------------
		--
		Set @message = 'Call Master_Sequences.dbo.CreateTempSequenceTables for job ' + @jobStr
		Set @CurrentLocation = @message
		If @logLevel >= 2
			execute PostLogEntry 'Progress', @message, 'UpdateSequenceModsForOneAnalysisBulk'
		--
		-- Warning: Update @MasterSequencesServerName above if changing from ProteinSeqs2 to another computer
		exec ProteinSeqs2.Master_Sequences.dbo.CreateTempSequenceTables @PeptideSequencesTableName output, @UniqueSequencesTableName output
		--
		SELECT @myRowcount = @@rowcount, @myError = @@error
		--
		if @myError <> 0
		begin
			set @message = 'Problem calling CreateTempSequenceTables to create the temporary sequence tables for job ' + @jobStr
			goto Done
		end
		else
			set @DeleteTempTables = 1

		If @SkipDeleteTempTables <> 0
			Set @DeleteTempTables = 0
			

		-----------------------------------------------------------
		-- Populate @PeptideSequencesTableName with the data to parse
		-----------------------------------------------------------
		--
		Set @message = 'Populate ' + @MasterSequencesServerName + '.' + @PeptideSequencesTableName + ' with candidate sequences for job ' + @jobStr
		Set @CurrentLocation = @message
		If @logLevel >= 2
			execute PostLogEntry 'Progress', @message, 'UpdateSequenceModsForOneAnalysisBulk'
		--
		Set @Sql = ''
		Set @Sql = @Sql + ' INSERT INTO ' + @MasterSequencesServerName + '.' + @PeptideSequencesTableName + ' (Peptide_ID, Peptide)'
		If @MaxRowsToProcess > 0
			Set @Sql = @Sql + ' SELECT TOP ' + Convert(varchar(12), @MaxRowsToProcess) + ' Peptide_ID, Peptide'
		Else
			Set @Sql = @Sql + ' SELECT Peptide_ID, Peptide'
		Set @Sql = @Sql + ' FROM T_Peptides'
		Set @Sql = @Sql + ' WHERE Job = ' + @jobStr
		If @SkipPeptidesFromReversedProteins <> 0
			Set @Sql = @Sql + ' AND State_ID <> 2'
		If @OnlyProcessNullSeqIDRows <> 0
			Set @Sql = @Sql + ' AND Seq_ID Is Null'
		--
		If @infoOnly <> 0
			Print @sql
			
		Exec (@Sql)
		--
		SELECT @myRowcount = @@rowcount, @myError = @@error
		--
		if @myError <> 0
		begin
			set @message = 'Problem populating ' + @PeptideSequencesTableName + ' with the peptides to process for job ' + @jobStr
			goto Done
		end
		
		if @myRowCount = 0
		begin
			If @SkipPeptidesFromReversedProteins <> 0 And Exists (SELECT * FROM T_Peptides WHERE Job = @job)
				set @message = 'Warning: all peptides in job ' + @jobStr + ' have State_ID = 2, meaning they only map to Reversed Proteins'
			Else
				set @message = 'Unable to populate ' + @MasterSequencesServerName + '.' + @PeptideSequencesTableName + ' with candidate sequences for job ' + @jobStr + '; it is likely this job does not have any peptides in T_Peptides'
			
			set @message = @message + '; Process_state for this job will be set to 5'
			Set @NextProcessState = 5

			If @infoOnly <> 0
				Print @Message
			Else
			Begin
				Set @CurrentLocation = 'Update state for job ' + @jobStr + ' to ' + Convert(varchar(12), @NextProcessState)
				Exec SetProcessState @job, @NextProcessState
			End

			Set @myError = 51113
			Goto Done
		end
		
		-----------------------------------------------------------
		-- Call GetIDsForRawSequences to process the data in the temporary sequence tables
		-----------------------------------------------------------
		--
		set @message = 'Call Master_Sequences.dbo.GetIDsForRawSequences for job ' + @jobStr
		Set @CurrentLocation = @message
		If @logLevel >= 1
			execute PostLogEntry 'Progress', @message, 'UpdateSequenceModsForOneAnalysisBulk'
		--
		If @infoOnly = 0
			exec @myError = ProteinSeqs2.Master_Sequences.dbo.GetIDsForRawSequences @parameterFileName, @OrganismDBFileID, @ProteinCollectionFileID,
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
		set @message = 'Add new sequences to T_Sequence for job ' + @jobStr
		Set @CurrentLocation = @message
		If @logLevel >= 1
			execute PostLogEntry 'Progress', @message, 'UpdateSequenceModsForOneAnalysisBulk'
		--
		Set @Sql = ''
		Set @Sql = @Sql + ' INSERT INTO T_Sequence (Seq_ID, Clean_Sequence, Mod_Count, Mod_Description)'
		Set @Sql = @Sql + ' SELECT S.Seq_ID, S.Clean_Sequence, S.Mod_Count, S.Mod_Description'
		Set @Sql = @Sql + ' FROM ' + @MasterSequencesServerName + '.' + @UniqueSequencesTableName + ' AS S' 
		Set @Sql = @Sql + '    LEFT OUTER JOIN T_Sequence ON S.Seq_ID = T_Sequence.Seq_ID'
		Set @Sql = @Sql + ' WHERE T_Sequence.Seq_ID IS NULL'
		--
		If @infoOnly <> 0
			Print @Sql
		Else
			Exec (@Sql)
		--
		SELECT @myError = @@error, @myRowcount = @@rowcount
		--
		Set @sequencesAdded = @myRowCount
		
		
		-----------------------------------------------------------
		-- Update T_Peptides
		-----------------------------------------------------------
		--
		set @message = 'Update Seq_ID in T_Peptides for job ' + @jobStr
		Set @CurrentLocation = @message
		If @logLevel >= 1
			execute PostLogEntry 'Progress', @message, 'UpdateSequenceModsForOneAnalysisBulk'
		--
		Set @Sql = ''
		Set @Sql = @Sql + ' UPDATE T_Peptides'
		Set @Sql = @Sql + ' SET Seq_ID = P.Seq_ID'
		Set @Sql = @Sql + ' FROM ' + @MasterSequencesServerName + '.' + @PeptideSequencesTableName + ' AS P' 
		Set @Sql = @Sql + '    INNER JOIN T_Peptides ON T_Peptides.Peptide_ID = P.Peptide_ID'
		--
		If @infoOnly <> 0
			Print @Sql
		Else
			Exec (@Sql)
		--
		SELECT @myError = @@error, @myRowcount = @@rowcount

		Set @processCount = @myRowCount


		-----------------------------------------------------------
		-- Update Cleavage_State_Max in T_Sequence for the peptides present in this job
		-----------------------------------------------------------
		--	
		set @message = 'Update Cleavage_State_Max in T_Sequence for job ' + @jobStr
		Set @CurrentLocation = @message
		If @logLevel >= 1
			execute PostLogEntry 'Progress', @message, 'UpdateSequenceModsForOneAnalysisBulk'
		--	
		If @infoOnly = 0
		Begin
			UPDATE T_Sequence
			SET Cleavage_State_Max = LookupQ.Cleavage_State_Max
			FROM T_Sequence Seq INNER JOIN (
				SELECT Pep.Seq_ID, MAX(ISNULL(PPM.Cleavage_State, 0)) AS Cleavage_State_Max
				FROM T_Peptides Pep INNER JOIN
					T_Peptide_to_Protein_Map PPM ON 
					Pep.Peptide_ID = PPM.Peptide_ID INNER JOIN
					T_Sequence ON Pep.Seq_ID = T_Sequence.Seq_ID
				WHERE Pep.Job = @job
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
			
	--		If @MaxRowsToProcess = 0
	--		Begin
	--			Set @CurrentLocation = 'Update state for job ' + @jobStr + ' to ' + Convert(varchar(12), @NextProcessState)
	--			Exec SetProcessState @job, @NextProcessState
	--		End
	--		Else
	--		Begin

			-- Only advance the state if all of the peptides now have Seq_ID values defined
			Set @myRowCount = 0
			
			SELECT @myRowCount = COUNT(*)
			FROM T_Peptides
			WHERE Job = @Job AND
				Seq_ID IS NULL AND
				(@SkipPeptidesFromReversedProteins = 0 OR
				@SkipPeptidesFromReversedProteins <> 0 AND
				State_ID <> 2)
			
			If @myRowCount > 0
			Begin
				Set @message = 'Job ' + @jobStr + ' has ' + Convert(varchar(12), @myRowCount) + ' rows in T_Peptides with null Seq_ID values; will not advance the state to ' + Convert(varchar(12), @NextProcessState)
				
				If @MaxRowsToProcess = 0
					Exec PostLogEntry 'Error', @message, 'UpdateSequenceModsForOneAnalysisBulk'
				Else
					Exec PostLogEntry 'Warning', @message, 'UpdateSequenceModsForOneAnalysisBulk'
			End
			Else
			Begin
				Set @CurrentLocation = 'Update state for job ' + @jobStr + ' to ' + Convert(varchar(12), @NextProcessState)
				Exec SetProcessState @job, @NextProcessState
			End

			set @count = @processCount
			set @message = 'Peptide sequence mods updated for job ' + @jobStr + '; Sequences processed: ' + convert(varchar(11), @processCount) + '; New sequences added: ' + convert(varchar(11), @sequencesAdded)
		End
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'UpdateSequenceModsForOneAnalysisBulk')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch		
	
Done:

	
	-----------------------------------------------------------
	-- Delete the temporary sequence tables, since no longer needed
	-----------------------------------------------------------
	--
	If @DeleteTempTables = 1
	Begin
		Begin Try
			Set @CurrentLocation = 'Delete temporary tables ' + @PeptideSequencesTableName + ' and ' + @UniqueSequencesTableName
			exec ProteinSeqs2.Master_Sequences.dbo.DropTempSequenceTables @PeptideSequencesTableName, @UniqueSequencesTableName
		End Try
		Begin Catch
			-- Error caught
			Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'UpdateSequenceModsForOneAnalysisBulk')
			exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
									@ErrorNum = @myError output, @message = @message output
		End Catch
	End

	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[UpdateSequenceModsForOneAnalysisBulk] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateSequenceModsForOneAnalysisBulk] TO [MTS_DB_Lite] AS [dbo]
GO
