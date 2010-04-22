/****** Object:  StoredProcedure [dbo].[GetProteinSequenceWithMods] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetProteinSequenceWithMods
/****************************************************
**
**	Desc:	Marks up the protein sequence with mod symbols
**
**			You must define the symbols to use for each ModName using @ModNamesAndSymbols
**			Will ignore any mods not defined in @ModNamesAndSymbols
**			Mod symbols can only be one character long
**
**	Auth:	mem
**	Date:	02/24/2010 mem - Initial Version
**			02/26/2010 mem - Added parameter @MinimumPMTQualityScore
**
*****************************************************/
(
	@RefID int,
	@MinimumPMTQualityScore real = 1,			-- Used to filter the entries in T_Mass_Tags
	@ModNamesAndSymbols varchar(2048) = 'Hexose=#, Plus1Oxy=*',
	@ProteinResiduesWithMods varchar(max) = '' output,
	@message varchar(512) = '' output,
	@DebugMode tinyint = 0
)
AS
	set nocount on
	
	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0
	
	Declare @EntryID int
	Declare @ResidueNum int
	Declare @ModSymbol char
	
	Declare @MaxLength int
	Declare @continue tinyint
	
	
	CREATE TABLE #TmpModsToProcess (
		ModName varchar(64),
		ModSymbol char
	)
	
	CREATE TABLE #TmpResiduesToUpdate (
		EntryID int identity(1,1),
		ResidueNum int,
		ModSymbol char
	)

	CREATE CLUSTERED INDEX #IX_TmpResiduesToUpdate ON #TmpResiduesToUpdate(EntryID)
	
	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------
	
	Set @MinimumPMTQualityScore = IsNull(@MinimumPMTQualityScore, 1)
	Set @ModNamesAndSymbols = IsNull(@ModNamesAndSymbols, '')
	Set @ProteinResiduesWithMods = ''
	Set @message = ''
	
	If @ModNamesAndSymbols = ''
	Begin
		Set @message = '@ModNamesAndSymbols is empty; nothing to do'
		Goto Done
	End
	
	
	---------------------------------------------------
	-- Populate #TmpModsToProcess
	---------------------------------------------------
	
	INSERT INTO #TmpModsToProcess (ModName, ModSymbol)
	SELECT Keyword, Substring(Value, 1,1)
	FROM dbo.udfParseKeyValueList(@ModNamesAndSymbols, ',', '=')
	WHERE IsNull(Value, '') <> ''
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error	
	
	If @DebugMode <> 0
		SELECT *
		FROM #TmpModsToProcess
		
	---------------------------------------------------
	-- Look for @RefID in T_Proteins
	---------------------------------------------------
	
	If Not Exists (SELECT * FROM T_Proteins where Ref_ID = @RefID)
	Begin
		Set @message = '@RefID Not found in T_Proteins; nothing to do'
		Goto Done
	End
	
	SELECT @ProteinResiduesWithMods = Protein_Sequence
	FROM T_Proteins 
	WHERE Ref_ID = @RefID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error	
	
	---------------------------------------------------
	-- Process each of the entries in T_Mass_Tag_Mod_Info for this protein
	-- Note: we cannot use T_Protein_Residue_Mods since we need to filter on PMT_Quality_Score
	-- Limit the processing to the entries matching @ModNamesAndSymbols
	---------------------------------------------------
	
	INSERT INTO #TmpResiduesToUpdate (ResidueNum, ModSymbol)
	SELECT MTPM.Residue_Start + MTM.Mod_Position - 1 AS Residue_Num,
	       #TmpModsToProcess.ModSymbol
	FROM T_Mass_Tag_Mod_Info MTM
	     INNER JOIN #TmpModsToProcess
	       ON MTM.Mod_Name = #TmpModsToProcess.ModName
	     INNER JOIN T_Mass_Tags MT
	       ON MTM.Mass_Tag_ID = MT.Mass_Tag_ID
	     INNER JOIN T_Mass_Tag_to_Protein_Map MTPM
	       ON MTM.Mass_Tag_ID = MTPM.Mass_Tag_ID
	WHERE (MTPM.Ref_ID = @RefID) AND
	      (MT.PMT_Quality_Score >= @MinimumPMTQualityScore)
	GROUP BY MTPM.Residue_Start + MTM.Mod_Position - 1, #TmpModsToProcess.ModSymbol
	ORDER BY Residue_Num Desc


	If @DebugMode <> 0	
		SELECT *
		FROM #TmpResiduesToUpdate
		ORDER BY EntryID

	Set @MaxLength = DataLength(@ProteinResiduesWithMods) * 2
	
	If @MaxLength < 100
		set @MaxLength = 100

	If @DebugMode <> 0
		print @ProteinResiduesWithMods
	
	Set @EntryID = 0
	Set @continue = 1
	While @Continue = 1
	Begin
		SELECT TOP 1 @EntryID = EntryID,
		             @ResidueNum = ResidueNum,
		             @ModSymbol = ModSymbol
		FROM #TmpResiduesToUpdate
		WHERE EntryID > @EntryID
		ORDER BY EntryID

		--
		SELECT @myRowCount = @@rowcount, @myError = @@error	
		
		If @myRowCount = 0
			set @continue = 0
		Else
		Begin
			Set @ProteinResiduesWithMods = SubString(@ProteinResiduesWithMods, 1, @ResidueNum) + @ModSymbol + SubString(@ProteinResiduesWithMods, @ResidueNum+1, @MaxLength)

			If @DebugMode <> 0 And @EntryID % 10 = 0
				print @ProteinResiduesWithMods
		End
	
	End
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	
	return @myError


GO
