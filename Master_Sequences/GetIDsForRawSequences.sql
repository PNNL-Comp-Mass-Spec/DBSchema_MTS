/****** Object:  StoredProcedure [dbo].[GetIDsForRawSequences] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetIDsForRawSequences
/****************************************************
** 
**      ==========================================================================
**         NOTE: This is a legacy procedure that processes peptides one at a time
**               It is preferable to process sequences in bulk using ProcessCandidateSequences
**               Furthermore, ProcessCandidateSequences supports fuzzy matching for peptides with unknown-named modifications
**      ==========================================================================
**
**	Desc:  
**		Processes each of the peptide sequences in the given table (typically located in TempDB)
**		Calls GetIDFromRawSequence for each, and updates the table with the appropriate information
**		The sequences should be in the form A.BCDEFGHIJK.L
**
**		The peptide sequences table must contain the columns Peptide_ID, Peptide, and Seq_ID
**		A second table must also be provided to store the unique sequence information
**		This table must contain the columns Seq_ID, Clean_Sequence, Mod_Count, and Mod_Description
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	02/10/2005
**			02/16/2005 mem - Removed hard-coding of the database containing SP GetIDFromRawSequence
**			02/26/2005 dj/mem - Added bulk updating of the Seq_ID values for known, unmodified sequences in @PeptideSequencesTableName
**			06/09/2006 mem - Added support for Protein Collection File IDs and removed input parameter @organismDBName
**    
*****************************************************/
(
	@parameterFileName varchar(128),					-- Parameter file name associated with the given sequences
	@OrganismDBFileID int=0,							-- Organism DB file ID; if @OrganismDBFileID is non-zero, then @ProteinCollectionFileID is ignored; adds SeqID and MapID to T_Seq_Map if non-zero and not yet present
	@ProteinCollectionFileID int=0,						-- Protein collection file ID; adds SeqID and MapID to T_Seq_Map if non-zero and not yet present
	@PeptideSequencesTableName varchar(256),			-- Table with peptide sequences to read, populates the Seq_ID column in this table
	@UniqueSequencesTableName varchar(256),				-- Table to store the unique sequence information
	@count int=0 output,								-- Number of peptides processed
	@message varchar(256) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @S nvarchar(2048)
	declare @result int

	declare @SqlGetNext nvarchar(1024)
	Declare @SqlGetNextParamDef nvarchar(512)

	declare @SqlCheckUniqueSeq nvarchar(1024) 
	declare @SqlCheckUniqueSeqParamDef nvarchar(512) 
	
	declare @SqlNewUniqueSeq nvarchar(1024) 
	declare @SqlNewUniqueSeqParamDef nvarchar(512) 

	declare @SqlUpdateSeqID nvarchar(1024)
	declare @SqlUpdateSeqIDParamDef nvarchar(512)
	
	declare @peptideID int
	declare @Peptide varchar(3500)
	declare @PeptidePrevious varchar(3500)
	
	declare @sequencesAdded int
	declare @paramFileFound tinyint

	Set @sequencesAdded = 0	
	Set @paramFileFound = 0

	declare @paramFileID int
	declare @PM_TargetSymbolList varchar(128)
	declare @PM_MassCorrectionTagList varchar(512)
	declare @NP_MassCorrectionTagList varchar(512)
	set @PM_TargetSymbolList = ''
	set @PM_MassCorrectionTagList = ''
	set @NP_MassCorrectionTagList = ''

	
	declare @ProteinNTerminusMod tinyint
	declare @ProteinCTerminusMod tinyint

	declare @Working_Target_Symbol_List varchar(256)
	set @Working_Target_Symbol_List = '' 


	--------------------------------------------
	-- Check for blank Parameter file
	--------------------------------------------
	if IsNull(@parameterFileName, '') = ''
	begin
		set @message = 'Parameter file cannot be empty'
		goto Done
	end

	
 	-----------------------------------------------------------
	-- Look for the parameter file in T_Param_File_Mods_Cache
	-- to get modification info
	-----------------------------------------------------------
	
	exec @myError = GetParamFileModInfo
						@parameterFileName,
						@paramFileID output ,
						@paramFileFound output ,
						@PM_TargetSymbolList output ,
						@PM_MassCorrectionTagList output ,
						@NP_MassCorrectionTagList output,
						@message output
	--
	if @myError <> 0 or @paramFileFound = 0
	begin
		if @paramFileFound = 0
			set @message = 'Could not find parameter file: ' + @parameterFileName 
		else
			set @message = 'Error calling GetParamFileModInfo: ' + Convert(varchar(9), @myError)
		goto Done
	end

	-- Now that the parameter file information has been obtained, clear @parameterFileName
	-- in order to force the use of the cached mod params from the GetIDFromRawSequence arguments
	Set @parameterFileName = ''
	
	
	--------------------------------------------
	-- Look for unmodified peptides in @PeptideSequencesTableName whose Seq_ID values are already known
	-- Pre-update their Seq_ID values in bulk
	-- We cannot bulk update if @PM_MassCorrectionTagList contains the peptide terminus mod symbols (< or >)
	--------------------------------------------
    
    If @PM_TargetSymbolList NOT LIKE '%[<>]%'
    Begin
		-- Populate @Working_Target_Symbol_List
		Set @Working_Target_Symbol_List = @PM_TargetSymbolList
		
		-- Exclude from the bulk update those peptides matching symbols 
		--  in the target symbol list
		-- If [ or ] is in the target symbol list, then exclude peptides
		--  at the N or C terminus of the protein

		-- Handle square brackets: [ = Protein N Terminus, ] = Protein C Terminus
		set @ProteinNTerminusMod = 0
		if charindex('[', @Working_Target_Symbol_List) > 0
		begin
			set @ProteinNTerminusMod = 1 
			set @Working_Target_Symbol_List = replace(@Working_Target_Symbol_List, '[', '')
		end

		set @ProteinCTerminusMod = 0
		if charindex(']', @Working_Target_Symbol_List) > 0
		begin
			set @ProteinCTerminusMod = 1 
			set @Working_Target_Symbol_List = replace(@Working_Target_Symbol_List, ']', '')
		end

		-- Remove commas
		set @Working_Target_Symbol_List = replace(@Working_Target_Symbol_List, ',' , '')
		
		-- Construct the like clause
		set @Working_Target_Symbol_List = '''%['  + @Working_Target_Symbol_List + ']%'''


		-- Look for peptides in @PeptideSequencesTableName that do not contain any of the symbols in @Working_Target_Symbol_List
		-- Dynamic mods will have symbols like *, #, or @
		-- Static mods will have a letter present in @Working_Target_Symbol_List; thus, sequences that contain any of the
		--   static mod symbols will be excluded from the Update, and instead will be processed during the call to GetIDFromRawSequence
		-- Mod symbols of [ or ] apply to the N or C terminus of a protein, and, if present, 
		--  means that we cannot bulk update N or C terminus peptides
		
		set @S = ''		
		set @S = @S + ' UPDATE ' + @PeptideSequencesTableName
		set @S = @S + ' SET Seq_ID = Master.Seq_ID '
		set @S = @S + ' FROM ' + @PeptideSequencesTableName + ' AS pep INNER JOIN '
		set @S = @S +   ' Master_Sequences.dbo.T_Sequence AS Master ON '
		set @S = @S +   ' SubString(pep.peptide, 3, Len(pep.peptide)-4) = Master.Clean_Sequence AND'
		set @S = @S +   ' Master.Mod_Count = 0'
		set @S = @S + ' WHERE SubString(pep.peptide, 3, Len(pep.peptide)-4) NOT LIKE ' + @Working_Target_Symbol_List
		if @ProteinNTerminusMod > 0
			set @S = @S + ' and LEFT(pep.Peptide,1) <> ''-'' '
		if @ProteinCTerminusMod > 0
			set @S = @S + ' and RIGHT(pep.Peptide,1) <> ''-'' '

		exec @result = sp_executesql @S
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		if @myRowCount > 0
		Begin
			-- Need to populate @UniqueSequencesTableName with the sequences newly defined in @PeptideSequencesTableName
			set @S = ''
			set @S = @S + ' INSERT INTO ' + @UniqueSequencesTableName + ' (Seq_ID, Clean_Sequence, Mod_Count, Mod_Description)'
			set @S = @S + ' SELECT Seq_ID, SubString(pep.peptide, 3, Len(pep.peptide)-4) AS Clean_Sequence,'
			set @S = @S +         '0 AS Mod_Count, '''' AS Mod_Description'
			set @S = @S + ' FROM ' + @PeptideSequencesTableName + ' AS pep'
			set @S = @S + ' WHERE NOT (pep.Seq_ID IS NULL)'
			set @S = @S + ' GROUP BY Pep.Seq_ID, SubString(pep.peptide, 3, Len(pep.peptide)-4)'

			exec @result = sp_executesql @S
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

		End
	End
	
	-----------------------------------------------------------
	-- loop through all peptides in @PeptideSequencesTableName and process them
	-----------------------------------------------------------
	--
	declare @peptideAvailable int
	set @peptideAvailable = 1
	
	declare @seqID int
	declare @cleanSequence varchar(512)
	declare @modCount int
	declare @modDescription varchar(2048)

	set @seqID = 0
	set @cleanSequence = ''
	set @modCount = 0
	set @modDescription = ''
	
	-----------------------------------------------------------
	-- Look up the smallest Peptide_ID in @PeptideSequencesTableName
	-- that has a Null Seq_ID value
	-----------------------------------------------------------
	--
	Set @S = ''
	Set @S = @S + ' SELECT TOP 1 @PeptideID = Peptide_ID'
	Set @S = @S + ' FROM ' + @PeptideSequencesTableName
	Set @S = @S + ' WHERE Seq_ID IS NULL'
	Set @S = @S + ' ORDER BY Peptide_ID ASC'
	
	Set @SqlGetNextParamDef = '@PeptideID int output'
	exec @result = sp_executesql @S, @SqlGetNextParamDef, @PeptideID = @PeptideID output
	--
	SELECT @myError = @@error, @peptideAvailable = @@rowcount
	--
	Set @PeptideID = @PeptideID-1
	
	Set @PeptidePrevious = ''
	

	-----------------------------------------------------------
	-- Define the Sql that will be used during the While loop
	-----------------------------------------------------------
	--
	Set @SqlGetNext = ''
	Set @SqlGetNext = @SqlGetNext + ' SELECT TOP 1 @Peptide = Peptide, @PeptideID = Peptide_ID'
	Set @SqlGetNext = @SqlGetNext + ' FROM ' + @PeptideSequencesTableName
	Set @SqlGetNext = @SqlGetNext + ' WHERE Peptide_ID > @PeptideID AND Seq_ID IS NULL'
	Set @SqlGetNext = @SqlGetNext + ' ORDER BY Peptide_ID ASC'
	
	Set @SqlGetNextParamDef = '@Peptide varchar(850) output, @PeptideID int output'


	Set @SqlCheckUniqueSeq = ''
	Set @SqlCheckUniqueSeq = @SqlCheckUniqueSeq + ' SELECT @myRowCount = COUNT(Seq_ID)'
	Set @SqlCheckUniqueSeq = @SqlCheckUniqueSeq + ' FROM ' + @UniqueSequencesTableName
	Set @SqlCheckUniqueSeq = @SqlCheckUniqueSeq + ' WHERE Seq_ID = @seqID'

	Set @SqlCheckUniqueSeqParamDef = '@seqID int, @myRowCount int output'


	Set @SqlNewUniqueSeq = ''
	Set @SqlNewUniqueSeq = @SqlNewUniqueSeq + ' INSERT INTO ' + @UniqueSequencesTableName
	Set @SqlNewUniqueSeq = @SqlNewUniqueSeq + ' (Seq_ID, Clean_Sequence, Mod_Count, Mod_Description)'
	Set @SqlNewUniqueSeq = @SqlNewUniqueSeq + ' VALUES (@seqID, @cleanSequence, @modCount, @modDescription)'

	Set @SqlNewUniqueSeqParamDef = '@seqID int, @cleanSequence varchar(512), @modCount int, @modDescription varchar(2048)'

	
	Set @SqlUpdateSeqID = ''
	Set @SqlUpdateSeqID = @SqlUpdateSeqID + ' UPDATE ' + @PeptideSequencesTableName
	Set @SqlUpdateSeqID = @SqlUpdateSeqID + ' SET Seq_ID = @SeqID'
	Set @SqlUpdateSeqID = @SqlUpdateSeqID + ' WHERE Peptide_ID = @PeptideID'

	Set @SqlUpdateSeqIDParamDef = '@PeptideID int, @SeqID int'
	

	While @peptideAvailable > 0
	BEGIN --<main loop>

		-- get next unprocessed peptide
		--
		exec @result = sp_executesql @SqlGetNext, @SqlGetNextParamDef, @Peptide = @Peptide output, @PeptideID = @PeptideID output
		--
		SELECT @myError = @@error, @peptideAvailable = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Could not get next peptide from ' + @PeptideSequencesTableName
			goto Done
		end

		If @peptideAvailable > 0
		Begin
			-----------------------------------------------------------
			-- count the number of times through the loop
			--
			set @count = @count + 1

			-----------------------------------------------------------
			-- Lookup Seq_ID in the Master_Sequence DB
			-- Skip this if the current peptide sequence is the same as the previous sequence
			If Not (@Peptide = @PeptidePrevious)
			Begin
				-----------------------------------------------------------
				-- resolve the sequence ID
				--
				exec @myError = GetIDFromRawSequence
											@Peptide,
											@parameterFileName,
											0,								-- Pass 0 for @OrganismDBFileID so that T_Seq_Map is not updated
											0,								-- Pass 0 for @ProteinCollectionFileID so that T_Seq_to_Archived_Protein_Collection_File_Map is not updated
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
				if @myError <> 0 or IsNull(@paramFileFound,0) = 0
				begin
					if @myError = 0
						Set @myError = 4
						
					if @message is null
						set @message = 'Error calling GetIDFromRawSequence (' + convert(varchar(11), @myError) + ')'
					--
					goto Done
				end
				
				-----------------------------------------------------------
				-- Possibly add new sequence to @UniqueSequencesTableName
				--
				exec @result = sp_executesql @SqlCheckUniqueSeq, @SqlCheckUniqueSeqParamDef, @SeqID, @myRowCount = @myRowCount output
				
				If @myRowCount = 0 AND @result = 0
				Begin
				
					exec @result = sp_executesql @SqlNewUniqueSeq, @SqlNewUniqueSeqParamDef, @SeqID, @cleanSequence, @modCount, @modDescription
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
				
					Set @sequencesAdded = @sequencesAdded + 1
				End
				
				-- Update the Previous Peptide variable
				Set @PeptidePrevious = @Peptide
			End
			
			-----------------------------------------------------------
			-- Update the peptide's Seq_ID value
			--
			exec @result = sp_executesql @SqlUpdateSeqID, @SqlUpdateSeqIDParamDef, @PeptideID, @SeqID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0
			begin
				set @message = 'Could not update entry for peptide in ' + @PeptideSequencesTableName
				goto Done
			end
	
		End
		
	END --<main loop>


	-----------------------------------------------------------
	-- Add entries to T_Seq_Map or T_Seq_to_Archived_Protein_Collection_File_Map 
	-- for the updated sequences
	-----------------------------------------------------------
	--
	Exec StoreSeqIDMapInfo @OrganismDBFileID, @ProteinCollectionFileID, @UniqueSequencesTableName

	
Done:
	Return @myError

GO
GRANT EXECUTE ON [dbo].[GetIDsForRawSequences] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetIDsForRawSequences] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetIDsForRawSequences] TO [MTS_DB_Lite] AS [dbo]
GO
