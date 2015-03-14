/****** Object:  StoredProcedure [dbo].[UpdateProteinSeqsWithModsTable] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE dbo.UpdateProteinSeqsWithModsTable
/****************************************************
**
**	Desc:	Populates table T_Protein_SeqsWithMods with the protein sequences from T_Proteins,
**			but containing mod symbols as defined by @ModNamesAndSymbols
**
**			You must define the symbols to use for each ModName using @ModNamesAndSymbols
**			
**			Will ignore any mods not defined in @ModNamesAndSymbols
**			Mod symbols can only be one character long
**
**	Auth:	mem
**	Date:	02/24/2010 mem - Initial Version
**			02/26/2010 mem - Added parameter @MinimumPMTQualityScore and removed parameter @UpdateSeqsWithModsTable
**			04/28/2010 mem - Now passing parameter @ModNamesAndSymbols to procedure GetProteinSequenceWithMods
**			07/12/2010 mem - Added parameter @MinObsCountPassingFilter
**						   - Now posting a progress message every 5 minutes
**
*****************************************************/
(
	@RefIDMin int = 1,							-- Optional filter
	@RefIDMax int = 200,						-- Optional filter
	@MinimumPMTQualityScore real = 1,			-- Used to filter the entries in T_Mass_Tags
	@ModNamesAndSymbols varchar(2048) = 'Hexose=#, Plus1Oxy=*',
	@MinObsCountPassingFilter int = 0,			-- When non-zero, then filters out peptides with T_Mass_Tags.dbo.Peptide_Obs_Count_Passing_Filter less than this value
	@SkipExistingEntries tinyint = 1,			-- If @SkipExistingEntries is non-zero, then will skip proteins already present in T_Protein_SeqsWithMods
	@message varchar(512) = '' output
)
AS
	set nocount on
	
	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0
	
	Declare @RefID int
	Declare @ProteinResiduesWithMods varchar(max)
	
	Declare @continue tinyint
	Declare @ProteinsProcessed int
	Declare @ProteinsSkipped int

	Declare @TotalProteinsToProcess int
	Set @TotalProteinsToProcess = 0

	Declare @ProteinResidueCount int
	Declare @ModSymbolCount int
	
	Declare @LastLogTime datetime
	
	CREATE TABLE #Tmp_ProteinsToProcess (
		Ref_ID int NOT NULL
	)

	CREATE CLUSTERED INDEX #IX_Tmp_ProteinsToProcess ON #Tmp_ProteinsToProcess (Ref_ID)

	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------
	
	Set @MinimumPMTQualityScore = IsNull(@MinimumPMTQualityScore, 1)
	Set @RefIDMin = IsNull(@RefIDMin, 0)
	Set @RefIDMax = IsNull(@RefIDMax, 0)
	Set @ModNamesAndSymbols = IsNull(@ModNamesAndSymbols, '')
	set @MinObsCountPassingFilter = IsNull(@MinObsCountPassingFilter, 0)
	Set @SkipExistingEntries = IsNull(@SkipExistingEntries, 1)
	
	Set @message = ''
	
	If @ModNamesAndSymbols = ''
	Begin
		Set @message = '@ModNamesAndSymbols is empty; nothing to do'
		Goto Done
	End

	Set @ProteinsProcessed = 0
	Set @ProteinsSkipped = 0	
	
	---------------------------------------------------
	-- Update @RefIDMin and @RefIDMax if both are zero
	---------------------------------------------------
	
	If @RefIDMin = 0 And @RefIDMax = 0
	Begin
		SELECT @RefIDMin = MIN(Ref_ID), @RefIDMax = MAX(Ref_ID)
		FROM T_Proteins
	End

	---------------------------------------------------
	-- Populate #Tmp_ProteinsToProcess with the Ref_ID values to process T_Protein_SeqsWithMods
	---------------------------------------------------
	--
	INSERT INTO #Tmp_ProteinsToProcess (Ref_ID)	
	SELECT Ref_ID
	FROM T_Proteins
	WHERE Ref_ID BETWEEN @RefIDMin AND @RefIDMax
	ORDER BY Ref_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error	
	
	If @myRowCount = 0
	Begin
		Set @message = 'Did not find any proteins in T_Proteins with Ref_ID values between ' + Convert(varchar(12), @RefIDMin) + ' and ' + Convert(varchar(12), @RefIDMax)
		Goto Done
	End

	
	---------------------------------------------------
	-- Updating T_Protein_SeqsWithMods 
	---------------------------------------------------
	--
	
	If EXISTS (SELECT * FROM sys.tables WHERE name = 'T_Protein_SeqsWithMods')
	Begin
		If @SkipExistingEntries <> 0
		Begin
			-- Delete extra entries from #Tmp_ProteinsToProcess
			
			DELETE #Tmp_ProteinsToProcess
			FROM #Tmp_ProteinsToProcess Target
				INNER JOIN T_Protein_SeqsWithMods Source
				ON Source.Ref_ID = Target.Ref_ID
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error	
						
			SET @ProteinsSkipped = @myRowCount
		End		
	End
	Else
	Begin
		-- Table doesn't exist; need to create it
		CREATE TABLE T_Protein_SeqsWithMods (
			Ref_ID int NOT NULL,
			Protein_Sequence_with_Mods varchar(max),
			Protein_Residue_Count int,
			Mod_Symbol_Count int,
			Entered datetime DEFAULT GetDate()
		)
		
		CREATE UNIQUE CLUSTERED INDEX IX_T_Protein_SeqsWithMods ON T_Protein_SeqsWithMods (Ref_ID)
	End

	---------------------------------------------------
	-- Count the number of proteins to process
	---------------------------------------------------
	
	SELECT @TotalProteinsToProcess = COUNT(*)
	FROM #Tmp_ProteinsToProcess

	---------------------------------------------------
	-- Step through the proteins in #Tmp_ProteinsToProcess
	-- Call GetProteinSequenceWithMods for each
	---------------------------------------------------
	
	Set @RefID = @RefIDMin - 1
	Set @LastLogTime = GetDate()
	
	Set @continue = 1
	While @Continue = 1
	Begin
		SELECT TOP 1 @RefID = Ref_ID
		FROM #Tmp_ProteinsToProcess
		WHERE Ref_ID > @RefID
		ORDER BY Ref_ID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error	
		
		If @myRowCount = 0
			set @continue = 0
		Else
		Begin
			
			Exec @myError = GetProteinSequenceWithMods @RefID, 
													   @MinimumPMTQualityScore, 
													   @ModNamesAndSymbols,
													   @MinObsCountPassingFilter,
													   @ProteinResiduesWithMods=@ProteinResiduesWithMods output, 
													   @message = @message output
			
			Set @ProteinResidueCount = 0
			Set @ModSymbolCount = 0
			
			SELECT 
				@ProteinResidueCount = Prot.Protein_Residue_Count,
				@ModSymbolCount = DataLength(@ProteinResiduesWithMods) - Prot.Protein_Residue_Count
			FROM T_Proteins Prot
			WHERE Prot.Ref_ID = @RefID
			
			IF EXISTS (SELECT * FROM T_Protein_SeqsWithMods WHERE Ref_ID = @RefID)
			Begin
				-- Update the existing entry
				UPDATE T_Protein_SeqsWithMods
				SET Protein_Sequence_with_Mods = @ProteinResiduesWithMods,
					Protein_Residue_Count = @ProteinResidueCount,
					Mod_Symbol_Count = @ModSymbolCount,
					Entered = GetDate()
				WHERE Ref_ID = @RefID
			End
			Else
			Begin
				-- Add a new entry
				INSERT INTO T_Protein_SeqsWithMods( Ref_ID,
													Protein_Sequence_with_Mods,
													Protein_Residue_Count,
													Mod_Symbol_Count )
				VALUES (@RefID, @ProteinResiduesWithMods, @ProteinResidueCount, @ModSymbolCount)
			End
			
			If @myError <> 0
				Set @continue = 0
			
			Set @ProteinsProcessed = @ProteinsProcessed + 1
			
			If DateDiff(second, @LastLogTime, GetDate()) > 60*5
			Begin
				Set @message = '...Processing: ' + Convert(varchar(12), @ProteinsProcessed) + ' / ' + Convert(varchar(12), @TotalProteinsToProcess) + ' proteins'
				exec PostLogEntry 'Progress', @message, 'UpdateProteinSeqsWithModsTable'
				Set @message = ''
				
				Set @LastLogTime = GetDate()
			End
		End
	
	End
	

	---------------------------------------------------
	-- Log the changes to T_Log_Entries
	---------------------------------------------------		
	
	Set @message = 'Updated ' + Convert(varchar(12), @ProteinsProcessed) + ' entries in T_Protein_SeqsWithMods'
	If @ProteinsSkipped > 0
		Set @message = @message + '; skipped ' + Convert(varchar(12), @ProteinsSkipped) + ' proteins already present in T_Protein_SeqsWithMods'
	
	exec PostLogEntry 'Normal', @message, 'UpdateProteinSeqsWithModsTable'
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[UpdateProteinSeqsWithModsTable] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateProteinSeqsWithModsTable] TO [MTS_DB_Lite] AS [dbo]
GO
