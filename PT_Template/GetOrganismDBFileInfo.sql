/****** Object:  StoredProcedure [dbo].[GetOrganismDBFileInfo] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetOrganismDBFileInfo
/****************************************************
** 
**	Desc:	Determines the OrgDBFileID or Archived Protein Collection File ID for the given job
**			Also returns the number of Proteins and Residues in the given file
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	06/08/2006
**			06/13/2006 mem - Updated to parse out the ID value from the file in the Organism_DB_Name field if Protein_Collection_List <> 'na' and Protein_Collection_List <> ''
**			07/15/2006 mem - Updated to properly report when the GetArchivedFileIDForProteinCollectionList could not be found
**    
*****************************************************/
(
	@Job int,
	@OrganismDBFileID int=0 Output,			-- Will be 0 if the Organism_DB_Name is 'na' or '', if @ProteinCollectionFileID <> 0, or if the file is not found in MT_Main.dbo.V_DMS_Organism_DB_File_Import
	@ProteinCollectionFileID int=0 Output,	-- Will be 0 if the Protein_Collection_List is 'na' or '' or if the file is not known by the Protein_Sequences DB
	@ProteinCount int=0 Output,
	@ResidueCount int=0 Output,
	@message varchar(512)='' Output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Set @Job = IsNull(@Job, 0)
	Set @OrganismDBFileID = 0
	Set @ProteinCollectionFileID = 0
	Set @ProteinCount = 0 
	Set @ResidueCount = 0 
	Set @message = ''

	declare @OrganismDBName varchar(128)
	declare @ProteinCollectionList varchar(2048)
	declare @ProteinOptionsList varchar(256)
	set @OrganismDBName = ''
	set @ProteinCollectionList = ''
	set @ProteinOptionsList = ''

	declare @jobStr varchar(12)
	set @jobStr = cast(@job as varchar(12))
	
	declare @JobStrEx varchar(256)
	declare @IDText varchar(128)
	declare @CharLoc int
	
	-----------------------------------------------------------
	-- Lookup the parameters from analysis table
	-----------------------------------------------------------
	--
	SELECT	@OrganismDBName = Organism_DB_Name,
			@ProteinCollectionList = Protein_Collection_List,
			@ProteinOptionsList = Protein_Options_List
	FROM	T_Analysis_Description
	WHERE	Job = @job
	--
	SELECT @myError = @@error, @myRowcount = @@rowcount
	--
	If @myRowcount < 1 
	Begin
		set @message = 'Job ' + @jobStr + ' not found in T_Analysis_Description'
		set @myError = 60000
		goto Done
	End
	Else
	If @myError <> 0
	Begin
		set @message = 'Error looking up the Organism_DB_Name and Protein Collection info for job ' + @jobStr + ' in T_Analysis_Description (Error Code ' + Convert(varchar(12), @myError) + ')'
		goto Done
	End

	-----------------------------------------------------------
	-- get organism DB file ID or protein collection list archived file ID
	-----------------------------------------------------------
	
	If @ProteinCollectionList <> 'na' AND @ProteinCollectionList <> ''
	Begin
		-----------------------------------------------------------
		-- Protein Collection List
		-----------------------------------------------------------
		--
		Set @JobStrEx = @jobStr + '; "' + Left(@ProteinCollectionList,128) + '" and "' + Left(@ProteinOptionsList,64) + '" with OrgDBFile "' + @OrganismDBName + '"'
		
		If @OrganismDBName <> 'na' AND Len(@OrganismDBName) > 0
		Begin
			If Left(@OrganismDBName, 3) = 'ID_'
			Begin
				-- Filename is of the form: ID_001051_62C016D1.fasta
				-- Parse out the ID value that follows ID
				Set @IDText = SubString(@OrganismDBName, 4, Len(@OrganismDBName))
				
				-- Look for the next underscore
				Set @CharLoc = CharIndex('_', @IDText)
				
				If @CharLoc > 1
				Begin
					Set @IDText = Left(@IDText, @CharLoc-1)
					
					-- Note: The IsNumeric function will return a 1 if @IDText is 
					--  a series of numbers with a letter in the middle, for example '123d24'
					-- For this reason, we'll also test @IDText vs. '%[^0-9]%'
					--
					If IsNumeric(@IDText) <> 0 AND NOT @IDText LIKE '%[^0-9]%'
					Begin
						Set @ProteinCollectionFileID = Convert(int, @IDText)
						--print 'Extracted ID from filename'
					End
					Else
					Begin
						Set @message = 'Could not extract ID value from filename ' + @OrganismDBName + '; error converting text between underscores to an integer'
						execute PostLogEntry 'Error', @message, 'GetOrganismDBFileInfo', 8
						Set @message = ''
					End
				End
				Else
				Begin
					Set @message = 'Could not extract ID value from filename ' + @OrganismDBName + '; could not find the second underscore'
					execute PostLogEntry 'Error', @message, 'GetOrganismDBFileInfo', 8
					Set @message = ''
				End
			End
			Else
			Begin
				Set @message = 'Could not extract ID value from filename ' + @OrganismDBName + '; name does not start with ID_'
				execute PostLogEntry 'Error', @message, 'GetOrganismDBFileInfo', 8
				Set @message = ''
			End
		End
		
		If @ProteinCollectionFileID = 0
		Begin
			-- @OrganismDBName was 'na' or '' or @OrganismDBName did not start with ID_
			-- Call GetArchivedFileIDForProteinCollectionList to determine the ID value associated with @ProteinCollectionList and @ProteinOptionsList
			Set @myError = -9999
			Exec @myError = Gigasax.Protein_Sequences.dbo.GetArchivedFileIDForProteinCollectionList 
					@ProteinCollectionList, 
					@ProteinOptionsList, 
					@ArchivedFileID = @ProteinCollectionFileID output, 
					@message = @message output
			-- 
			If @myError <> 0
			Begin
				If @myError = -9999
					set @message = 'Could not find stored procedure Gigasax.Protein_Sequences.dbo.GetArchivedFileIDForProteinCollectionList; '
				Else
					set @message = 'Error calling Gigasax.Protein_Sequences.dbo.GetArchivedFileIDForProteinCollectionList for '
				
				set @message = @message + 'job ' + @JobStrEx + ' (Error Code ' + Convert(varchar(12), @myError) + ')'
				goto Done
			End

			--print 'Called Gigasax.Protein_Sequences.dbo.GetArchivedFileIDForProteinCollectionList to extract the ID'

			If @ProteinCollectionFileID = 0
			Begin
				set @message = 'Archived protein collections file not found in the Protein_Sequences DB for job ' + @JobStrEx
				set @myError = 60001
				goto Done
			End
		End

		SELECT	@ProteinCount = Protein_Count,
				@ResidueCount = Residue_Count
		FROM MT_Main.dbo.V_DMS_Protein_Collection_File_Stats_Import
		WHERE Archived_File_ID = @ProteinCollectionFileID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		-- 
		If @myRowCount = 0
		Begin
			set @message = 'Archived protein collections file ID ' + Convert(varchar(12), @ProteinCollectionFileID) + ' not found in MT_Main.dbo.V_DMS_Protein_Collection_File_Stats_Import for job ' + @JobStrEx
			set @myError = 60002
			goto Done
		End
		Else
		If @myError <> 0
		Begin
			set @message = 'Error looking up file ID ' + Convert(varchar(12), @ProteinCollectionFileID) + ' in MT_Main.dbo.V_DMS_Protein_Collection_File_Stats_Import for job ' + @JobStrEx + ' (Error Code ' + Convert(varchar(12), @myError) + ')'
			goto Done
		End

	End
	Else
	Begin
		-----------------------------------------------------------
		-- Traditional standalone fasta file
		-----------------------------------------------------------
		--
		SELECT	TOP 1 
				@OrganismDBFileID = ID,
				@ProteinCount = NumProteins,
				@ResidueCount = NumResidues
		FROM	MT_Main.dbo.V_DMS_Organism_DB_File_Import
		WHERE	FileName = @OrganismDBName
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myRowCount < 1 Or @OrganismDBFileID = 0 
		Begin
			set @message = 'Could not find Organism DB File ' + @OrganismDBName + ' in MT_Main.dbo.V_DMS_Organism_DB_File_Import for job ' + @jobStr
			set @myError = 60004
			goto done
		End
		Else
		If @myError <> 0
		Begin
			set @message = 'Error while looking up Organism DB File Stats from MT_Main for file ' + @OrganismDBName + ' for job ' + @jobStr + ' (Error Code ' + Convert(varchar(12), @myError) + ')'
			goto done
		End		
	End

		
Done:
	If @myError <> 0
	Begin
		If Len(@message) = 0
			Set @message = 'Error ID ' + Convert(varchar(12), @myError)
		execute PostLogEntry 'Error', @message, 'GetOrganismDBFileInfo', 8
	End
	
	Return @myError


GO