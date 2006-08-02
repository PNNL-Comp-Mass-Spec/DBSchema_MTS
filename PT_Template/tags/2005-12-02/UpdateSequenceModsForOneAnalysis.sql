SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UpdateSequenceModsForOneAnalysis]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[UpdateSequenceModsForOneAnalysis]
GO


CREATE Procedure dbo.UpdateSequenceModsForOneAnalysis
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
**				07/26/2004 grk - Extensive modification to use master sequence database
**				08/07/2004 mem - Added @paramFileFound logic
**				08/23/2004 grk - changed to consolidated mod description parameters
**				08/24/2004 mem - Added use of @cleanSequence, @modCount, and @modDescription with GetIDFromRawSequence
**				08/27/2004 grk - added section to get organism DB file ID and pass to master sequence
**				08/29/2004 mem - Added code optimization step to avoid unnecessary calls to the Master_Sequences DB
**				09/03/2004 mem - Stopped using #TTempPeptides to track the Peptide_ID values that need to be processed due to slow behavior from the temporary DB
**				02/09/2005 mem - Switched to using temporary tables to hold the new sequences and Seq_ID values
**				02/11/2005 mem - Added @logLevel parameter
**				02/21/2005 mem - Switched Master_Sequences location from PrismDev to Albert
**				09/29/2005 mem - Now populating Cleavage_State_Max in T_Sequence
**				10/10/2005 mem - Updated the Cleavage_State_Max population query to effectively store the max cleavage state across all jobs in T_Sequence, not just the max cleavage state for the given job
**    
*****************************************************/
	@NextProcessState int = 30,
	@job int,
	@count int=0 output,
	@message varchar(512)='' output,
	@logLevel tinyint = 1
As
	set nocount on
	
	declare @myError int
	set @myError = 0
	
	declare @myRowcount int
	set @myRowcount = 0
	
	set @message = ''

	declare @jobStr varchar(12)
	set @jobStr = cast(@job as varchar(12))
	
	declare @result int
	declare @peptideID int
	declare @Peptide varchar(3500)
	declare @PeptidePrevious varchar(3500)
	declare @numPeptides int
	
	declare @parameterFileName varchar(128)
	declare @paramFileFound tinyint
	
	declare @organismDBName varchar(128)
	declare @orgDBFileID int
	
	declare @processCount int
	set @processCount = 0
	
	declare @sequencesAdded int
	set @sequencesAdded = 0
		
	declare @transName varchar(32)

	-----------------------------------------------------------
	-- Get Analysis job information
	-----------------------------------------------------------
	--
	-- get parameters from analysis table, 
	--
	set @parameterFileName = ''
	set @organismDBName = ''
	set @paramFileFound = 0
	
	SELECT	@parameterFileName = Parameter_File_Name,
			@organismDBName = Organism_DB_Name
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

	-----------------------------------------------------------
	-- get organism DB file ID
	-----------------------------------------------------------
	
	set @orgDBFileID = 0

	SELECT @orgDBFileID = ID
	FROM MT_Main.dbo.V_DMS_Organism_DB_File_Import
	WHERE (FileName = @organismDBName)
	--
	SELECT @myRowcount = @@rowcount, @myError = @@error
	--
	if @orgDBFileID = 0
	begin
		set @message = 'Could not get organism DB file ID for job ' + @jobStr
		set @myError = 51112
		goto Done
	end


	-----------------------------------------------------------
	-- Create two temporary tables to cache the data to update
	-----------------------------------------------------------
	--
	CREATE TABLE #New_Sequences (
		Seq_ID int NOT NULL ,
		Clean_Sequence varchar(850) NOT NULL ,
		Mod_Count int NULL,
		Mod_Description varchar(2048) NULL
	)
	--
	SELECT @myRowcount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #New_Sequences'
		goto Done
	end

	CREATE UNIQUE INDEX #IX_New_Sequences ON #New_Sequences (Seq_ID)


	CREATE TABLE #Peptide_To_Seq_Map (
		Peptide_ID int NOT NULL,
		Seq_ID int NOT NULL
	)
	--
	SELECT @myRowcount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #New_Sequences'
		goto Done
	end

	CREATE UNIQUE INDEX #IX_Peptide_To_Seq_Map ON #Peptide_To_Seq_Map (Peptide_ID)
	
	
	-----------------------------------------------------------
	-- loop through all peptides for this job and process them
	-----------------------------------------------------------
	--
	declare @peptideAvailable int
	set @peptideAvailable = 1

	declare @lastProgressUpdate datetime
	Set @lastProgressUpdate = GetDate()
	
	declare @seqID int
	declare @PM_TargetSymbolList varchar(128)
	declare @PM_MassCorrectionTagList varchar(512)
	declare @NP_MassCorrectionTagList varchar(512)
	declare @cleanSequence varchar(512)
	declare @modCount int
	declare @modDescription varchar(2048)

	set @seqID = 0
	set @PM_TargetSymbolList = ''
	set @PM_MassCorrectionTagList = ''
	set @NP_MassCorrectionTagList = ''
	set @cleanSequence = ''
	set @modCount = 0
	set @modDescription = ''
	
	-----------------------------------------------------------
	--
	SELECT TOP 1 @PeptideID = Peptide_ID
	FROM T_Peptides
	WHERE Analysis_ID = @job
	ORDER BY Peptide_ID ASC
	--
	SELECT @myError = @@error, @peptideAvailable = @@rowcount
	--
	Set @PeptideID = @PeptideID-1
	
	Set @PeptidePrevious = ''
	
	While @peptideAvailable > 0
	BEGIN --<main loop>

		-- get next unprocessed peptide
		--
		SELECT TOP 1
				@Peptide = Peptide, 
				@PeptideID = Peptide_ID
		FROM  T_Peptides
		WHERE Analysis_ID = @job AND Peptide_ID > @PeptideID
		ORDER BY Peptide_ID ASC
		--
		SELECT @myError = @@error, @peptideAvailable = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Could not get next peptide for job ' + @jobStr
			goto Done
		end

		If @peptideAvailable > 0
		Begin
			-----------------------------------------------------------
			-- count the number of times through the loop
			--
			set @processCount = @processCount + 1
	
			if @logLevel >= 1
			Begin
				if @processCount % 1000 = 0 
				Begin
					if @processCount % 5000 = 0 Or DateDiff(second, @lastProgressUpdate, GetDate()) >= 90
					Begin
						set @message = '...Processing: ' + convert(varchar(11), @processCount)
						execute PostLogEntry 'Progress', @message, 'UpdateSequenceModsForOneAnalysis'
						set @message = ''
						set @lastProgressUpdate = GetDate()
					End
				End
			End
			
			-----------------------------------------------------------
			-- Lookup Seq_ID in Master_Sequence DB
			-- Skip this if the current peptide sequence is the same as the previous sequence
			If Not (@Peptide = @PeptidePrevious)
			Begin
				-----------------------------------------------------------
				-- resolve the sequence ID
				--
				set @myError = 2 -- in case call itself fails
				set @message = 'Failed to call Master_Sequence.dbo.GetIDFromRawSequence'
				--
				exec @myError = Albert.Master_Sequences.dbo.GetIDFromRawSequence
											@Peptide,
											@parameterFileName,
											@orgDBFileID,
											@paramFileFound output,
											@seqID output,
											@PM_TargetSymbolList  output,
											@PM_MassCorrectionTagList output,
											@NP_MassCorrectionTagList output,
											@cleanSequence output,
											@modCount output,
											@modDescription output,
											@message output
				--
				if @myError is null  -- can happen if procedure call fails
					set @myError = 3
				--
				if @myError <> 0 or IsNull(@paramFileFound,0) = 0
				begin
					if @myError = 0
						Set @myError = 4
						
					if @message is null
						set @message = 'Error calling Master_Sequences.dbo.GetIDFromRawSequence (' + convert(varchar(11), @myError) + ')'
					--
					goto Done
				end
				
				-----------------------------------------------------------
				-- Possibly add the new sequence to #New_Sequences
				--
				SELECT @myRowCount = COUNT(Seq_ID)
				FROM T_Sequence
				WHERE Seq_ID = @seqID
				--
				SELECT @myError = @@error
				
				If @myRowCount = 0 AND @myError = 0
				Begin
					SELECT @myRowCount = COUNT(Seq_ID)
					FROM #New_Sequences
					WHERE Seq_ID = @seqID
					
					If @myRowCount = 0 
					Begin
						INSERT INTO #New_Sequences (Seq_ID, Clean_Sequence, Mod_Count, Mod_Description)
						VALUES (@seqID, @cleanSequence, @modCount, @modDescription)
						--
						SELECT @myRowcount = @@rowcount, @myError = @@error
					
						Set @sequencesAdded = @sequencesAdded + 1
					End
				End
				
				-- Update the Previous Peptide variable
				Set @PeptidePrevious = @Peptide
			End
			
			-----------------------------------------------------------
			-- save results back into peptide
			--
			INSERT INTO #Peptide_To_Seq_Map (Peptide_ID, Seq_ID)
			VALUES (@peptideID, @seqID)
			--
			select @myError = @@error, @myRowcount = @@rowcount
			if @myError <> 0
			begin
				set @message = 'Could not update entry for peptide for job ' + @jobStr
				goto Done
			end
		End
		
		-- Clear @parameterFileName in order to force the use of 
		-- the cached mod params from the GetIDFromRawSequence arguments
		set @parameterFileName = '' 
		
	END --<main loop>


	-----------------------------------------------------------
	-- Add the new sequences to T_Sequence
	-----------------------------------------------------------
	--
	if @logLevel >= 2
	Begin
		SELECT @myRowCount = COUNT(Seq_ID)
		FROM #New_Sequences
		
		set @message = '...Processing: Add new sequences to T_Sequence'
		If @myRowCount = 0
			set @message = @message + '; nothing to do'
		Else
			set @message = @message + '; adding ' + convert(varchar(9), @myRowCount) + ' rows'
		
		execute PostLogEntry 'Progress', @message, 'UpdateSequenceModsForOneAnalysis'
		set @message = ''
	End
	
	INSERT INTO T_Sequence (Seq_ID, Clean_Sequence, Mod_Count, Mod_Description)
	SELECT #New_Sequences.Seq_ID, #New_Sequences.Clean_Sequence, #New_Sequences.Mod_Count, #New_Sequences.Mod_Description
	FROM #New_Sequences LEFT OUTER JOIN T_Sequence ON 
		 #New_Sequences.Seq_ID = T_Sequence.Seq_ID
	WHERE T_Sequence.Seq_ID IS NULL
	--
	SELECT @myRowcount = @@rowcount, @myError = @@error


	-----------------------------------------------------------
	-- Update T_Peptides
	-----------------------------------------------------------
	--
	if @logLevel >= 2
	Begin
		SELECT @myRowCount = COUNT(Peptide_ID)
		FROM #Peptide_To_Seq_Map
		
		set @message = '...Processing: Updating T_Peptides'
		If @myRowCount = 0
			set @message = @message + '; nothing to do'
		Else
			set @message = @message + '; updating ' + convert(varchar(9), @myRowCount) + ' rows'
		
		execute PostLogEntry 'Progress', @message, 'UpdateSequenceModsForOneAnalysis'
		set @message = ''
	End
	
	UPDATE T_Peptides
	SET Seq_ID = #Peptide_To_Seq_Map.Seq_ID
	FROM T_Peptides INNER JOIN #Peptide_To_Seq_Map ON 
		 T_Peptides.Peptide_ID = #Peptide_To_Seq_Map.Peptide_ID
	--
	SELECT @myRowcount = @@rowcount, @myError = @@error


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
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

