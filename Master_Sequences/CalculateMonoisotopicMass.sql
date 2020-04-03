/****** Object:  StoredProcedure [dbo].[CalculateMonoisotopicMass] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CalculateMonoisotopicMass]
/****************************************************
**
**	Desc: Calculates the monoisotopic mass for the
**		  peptides in T_Sequence
**
**	Returns the number of rows for which the mass was successfully calculated
**
**	Parameters:
**
**  Output:
**		@message - '' if successful, otherwise a message about what went wrong
**
**	Auth:	mem (modified version of CalculateMonoisotopicMass written by kal)
**	Date:	03/25/2004
**			03/27/2004 mem - Changed logic to store mass of 0 if an unknown symbol is found and it is not a letter
**			07/20/2004 mem - Added the @SequencesToProcess parameter and changed the @done variable to @continue
**			08/01/2004 mem - Changed T_Peptide_Mod_Global_List reference from MT_Main to a temporary table
**									version of V_DMS_Peptide_Mod_Global_List_Import
**			08/26/2004 mem - Updated to use consolidated mod descriptions and mass info views from DMS
**			07/01/2005 mem - Now updating column Last_Affected in T_Sequence
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**          04/11/2020 mem - Expand Mass_Correction_Tag to varchar(32)
**
*****************************************************/
(
	@message varchar(255) = '' output,
	@RecomputeAll tinyint = 0,					-- When 1, recomputes masses for all peptides; when 0, only computes if the mass is currently Null
	@AbortOnUnknownSymbolError tinyint = 0,		-- When 1, then aborts calculations if an unknown symbol is found
	@SequencesToProcess int = 0					-- When greater than 0, then only processes the given number of sequences
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Set @message = ''

	Declare @PeptidesProcessedCount int
	Set @PeptidesProcessedCount = 0

	Declare @Progress varchar(255)
	Declare @UpdateEnabled tinyint

	--used for storing information from each table row
	Declare @Seq_ID int
	Set @Seq_ID = -100000000
	Declare @peptide varchar(900)
	Set @peptide = ''
	Declare @orig_peptide varchar(900)  --same as peptide, but doesn't get truncated
	Set @orig_peptide = ' '				--While computing mass - used for making message on error

	--the calculated monoisotopic mass for the peptide
	Declare @mono_Mass float
	Set @mono_Mass = 0

	--used While looping through the peptide, adding the mass of each amino acid to the total
	Declare @currentAA char			--current amino acid
	Set @currentAA = ' '
	Declare @currentAAMass float
	Set @currentAAMass = 0

	--counts of atoms for current amino acid
	Declare @countC int
	Declare @countH int
	Declare @countN int
	Declare @countO int
	Declare @countS int

	--counts of atoms for entire peptide
	Declare @totalCountC int
	Declare @totalCountH int
	Declare @totalCountN int
	Declare @totalCountO int
	Declare @totalCountS int

	-- tells whether main loop has been completed
	Declare @continue int
	Set @continue = 1

	--------------------------------------------
	--Create temporary amino acid table
	--------------------------------------------
	CREATE TABLE #TMP_AA (
		[Symbol] [varchar] (16)  NOT NULL ,
		[Description] [varchar] (64)  NOT NULL ,
		[Num_C] [int] NOT NULL,
		[Num_H] [int] NOT NULL,
		[Num_N] [int] NOT NULL,
		[Num_O] [int] NOT NULL,
		[Num_S] [int] NOT NULL,
		[Average_Mass] [float] NOT NULL ,
		[Monoisotopic_Mass] [float] NOT NULL
	)

	CREATE UNIQUE INDEX #IX_TMP_AA_Symbol ON #TMP_AA (Symbol ASC)
	--------------------------------------------
	--and insert data
	--------------------------------------------
	/*Symbol,Abbreviation,C,H,N,O,S,Average,Mono
	'A','Ala',3,5,1,1,0,71.0792940261929,71.0371100902557
	'R','Arg',6,12,4,1,0,156.188618505844,156.101100921631
	'N','Asn',4,6,2,2,0,114.104471781515,114.042921543121
	'D','Asp',4,5,1,3,0,115.089141736421,115.026938199997
	'C','Cys',3,5,1,1,1,103.143682753682,103.009180784225
	'E','Glu',5,7,1,3,0,129.116199871857,129.042587518692
	'O','Orn',5,10,2,1,0,114.148110705429,114.079306125641
	'B','Asn/Asp',4,6,2,2,0,114.104471781515,114.042921543121
	'G','Gly',2,3,1,1,0,57.0522358907575,57.0214607715607
	'H','His',6,7,3,1,0,137.142015793981,137.058904886246
	'I','Ile',6,11,1,1,0,113.160468432499,113.084058046341
	'L','Leu',6,11,1,1,0,113.160468432499,113.084058046341
	'K','Lys',6,12,2,1,0,128.175168840864,128.094955444336
	'M','Met',5,9,1,1,1,131.197799024553,131.040479421616
	'F','Phe',9,9,1,1,0,147.177838231808,147.068408727646
	'Z','Gln/Glu',5,8,2,2,0,128.13152991695,128.058570861816
	'P','Pro',5,7,1,1,0,97.1174591453144,97.0527594089508
	'S','Ser',3,5,1,2,0,87.0786643894641,87.0320241451263
	'T','Thr',4,7,1,2,0,101.1057225249,101.047673463821
	'W','Trp',11,10,2,1,0,186.214752607545,186.079306125641
	'Y','Tyr',9,9,1,2,0,163.177208595079,163.063322782516
	'V','Val',5,9,1,1,0,99.1334102970637,99.0684087276459
	'Q','Gln',5,8,2,2,0,128.13152991695,128.058570861816
	'X','unknown',5,8,2,2,0,128.13152991695,128.058570861816
	'H2O','Water(Peptide Ends)',0,2,0,1,0,18.01528,18.010563
	*/

	INSERT INTO #TMP_AA (Symbol, Description, Num_C, Num_H, Num_N,
		Num_O, Num_S, Average_Mass, Monoisotopic_Mass)
	SELECT Residue_Symbol, Description, Num_C, Num_H, Num_N,
		Num_O, Num_S, Average_Mass, Monoisotopic_Mass
	FROM V_DMS_Residues
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	If @myError <> 0
	Begin
		Set @message = 'Failure in setting up temporary amino acid table'
		Goto done
	End

	-- Also add the values for Water
	INSERT INTO #TMP_AA
	VALUES ('H2O','Water(Peptide Ends)',0,2,0,1,0,18.01528,18.0105633)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


	-- Variables for processing Modifications
	Declare @RowCountRemaining int

	Declare @MassCorrectionTag varchar(32)
	Declare @MassCorrectionMass float		--mass to add for the current modification
	Declare @ModAffectedAtom char(1)		--for isotopic-based mods, the atom that is affected (e.g. N)

	Declare @modFound tinyint

	CREATE TABLE #MassCorrectionFactors (
		[Mass_Correction_ID] [int] NOT NULL ,
		[Mass_Correction_Tag] [varchar] (32) NOT NULL ,
		[Monoisotopic_Mass] [float] NOT NULL ,
		[Affected_Atom] [char] (1) NOT NULL ,
	)

	Declare @ModTableInitialized tinyint = 0

	-- The following table holds the list of modifications that apply to the given peptide
	CREATE TABLE #PeptideModList (
		[Mass_Correction_Tag] [varchar] (32) NOT NULL ,
		[Position] int NOT NULL,
		[Monoisotopic_Mass] [float] NOT NULL ,
		[Affected_Atom] [char] (1) NOT NULL ,
		[UniqueModID] [int] IDENTITY
	)

	CREATE UNIQUE INDEX #IX_PeptideModList_UniqueModID ON #PeptideModList (UniqueModID)

	Declare @UniqueModID int
	Set @UniqueModID = -1

	-----------------------------------------------
	--Loop through each entry in T_Sequence table, computing monoisotopic mass if possible
	-----------------------------------------------
	While @continue > 0
	Begin
		If @RecomputeAll <> 0
			--read data for one peptide into local variables
			SELECT TOP 1
					@Seq_ID = Seq_ID,
					@peptide = dbo.T_Sequence.Clean_Sequence,
					@orig_peptide = dbo.T_Sequence.Clean_Sequence
			FROM dbo.T_Sequence
			WHERE Seq_ID > @Seq_ID
			ORDER BY Seq_ID ASC
		Else
			--read data for one peptide into local variables
			SELECT TOP 1
					@Seq_ID = Seq_ID,
					@peptide = dbo.T_Sequence.Clean_Sequence,
					@orig_peptide = dbo.T_Sequence.Clean_Sequence
			FROM dbo.T_Sequence
			WHERE Seq_ID > @Seq_ID AND Monoisotopic_Mass IS Null
			ORDER BY Seq_ID ASC

		--check for errors in loading
		SELECT @myError = @@error, @myRowCount = @@rowcount
		If @myError <> 0
		Begin
			Set @message = 'Error in reading peptide info from table.'
			Goto done
		End
		If @myRowCount = 0 -- we're done
		Begin
			Set @message = ''
			Set @myError = 0
			Goto done
		End
		Set @continue = @myRowCount

		If @ModTableInitialized = 0
		Begin
			-- Create a temporary table version of V_DMS_Monoisotopic_Masss
			-- Doing this here, rather than above, since we only need to cache this
			-- information if one or more sequences needs to have its mass calculated
			INSERT INTO #MassCorrectionFactors ( Mass_Correction_ID, Mass_Correction_Tag, Monoisotopic_Mass, Affected_Atom)
			SELECT Mass_Correction_ID, Mass_Correction_Tag,
					IsNull(Monoisotopic_Mass_Correction, 0),
					IsNull(Affected_Atom, '-')
			FROM V_DMS_Mass_Correction_Factors
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			If @myError <> 0 or @myRowCount = 0
			Begin
				Set @message = 'Error populating #MassCorrectionFactors temporary table'
				Goto done
			End

			Set @ModTableInitialized = 1
		End

		---------------------------------------
		--compute monoisotopic mass
		---------------------------------------
		Set @mono_mass = 0
		Set @totalCountC = 0
		Set @totalCountH = 0
		Set @totalCountN = 0
		Set @totalCountO = 0
		Set @totalCountS = 0

		--------------------------------------------
		--loop through characters in peptide,
		--adding mass to total for each one
		--------------------------------------------
		While Len(@peptide) > 0
		Begin
			--extract first character from peptide string, then set the peptide
			--to the remainder
			Set @currentAA = SubString(@peptide, 1, 1)
			Set @peptide = SubString(@peptide, 2, Len(@peptide) - 1)

			--lookup mass for this amino acid
			SELECT  @currentAAMass = Monoisotopic_Mass,
					@countC = Num_C,
					@countH = Num_H,
					@countN = Num_N,
					@countO = Num_O,
					@countS = Num_S
			FROM #TMP_AA
			WHERE Symbol = @currentAA

			--check for errors
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @myError <> 0
			Begin
				Set @message = 'Error in looking up mass in temp table for symbol ' + @currentAA
				Goto done
			End

			If @myRowCount = 0
			Begin
				Set @message = 'Unknown symbol ' + @currentAA + ' for Seq_ID ' + Convert(varchar(11), @Seq_ID) + ', ' + @orig_peptide
				Execute PostLogEntry 'Error', @message, 'CalculateMonoisotopicMass'
				If Upper(@currentAA) < 'A' Or Upper(@currentAA) > 'Z'
				Begin
					Set @mono_mass = 0
					Goto UpdateMass
				End

				If (@AbortOnUnknownSymbolError <> 0)
				Begin
					Set @myError = 75005
					Goto done
				End
			End
			Else
			Begin
				--add mass of amino acid to current total
				Set @mono_mass = @mono_mass + @currentAAMass
				Set @totalCountC = @totalCountC + @countC
				Set @totalCountH = @totalCountH + @countH
				Set @totalCountN = @totalCountN + @countN
				Set @totalCountO = @totalCountO + @countO
				Set @totalCountS = @totalCountS + @countS
			End

		End --End of looping through peptide sequence

		--add in cap
		SELECT  @currentAAMass = Monoisotopic_Mass,
					@countC = Num_C,
					@countH = Num_H,
					@countN = Num_N,
					@countO = Num_O,
					@countS = Num_S
		FROM #TMP_AA
		WHERE Symbol = 'H2O'

		Set @mono_mass = @mono_mass + @currentAAMass
		Set @totalCountC = @totalCountC + @countC
		Set @totalCountH = @totalCountH + @countH
		Set @totalCountN = @totalCountN + @countN
		Set @totalCountO = @totalCountO + @countO
		Set @totalCountS = @totalCountS + @countS


		---------------------------------------
		-- Now deal with positional modifications
		---------------------------------------

		-- We can use a simple Select query to add all of the modification masses
		-- to @mono_Mass
		--
		SELECT	@mono_mass = @mono_mass + #MassCorrectionFactors.Monoisotopic_Mass
		FROM	T_Sequence INNER JOIN
				T_Mod_Descriptors ON T_Sequence.Seq_ID = T_Mod_Descriptors.Seq_ID LEFT OUTER JOIN
				#MassCorrectionFactors ON LTrim(RTrim(#MassCorrectionFactors.Mass_Correction_Tag)) = LTrim(RTrim(T_Mod_Descriptors.Mass_Correction_Tag))
		WHERE   T_Sequence.Seq_ID = @Seq_ID AND
				#MassCorrectionFactors.Affected_Atom = '-'
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0
		Begin
			Set @message = 'Error updating the mass to include modification masses for Seq_ID ' + Convert(varchar(11), @Seq_ID) + ', ' + @orig_peptide
			Goto done
		End


		---------------------------------------
		--now deal with isotopic modifications
		---------------------------------------

		-- Note: Rather than using Truncate Table after every sequence to clear #PeptideModList, it is
		--       more efficient to continually add new modifications to the table as peptides are processed
		--       and only Truncate the table every 1000 sequences (arbitrary value)
		-- Continual use of Truncate Table actually slows down this procedure due to drastically increased disk activity

		If @UniqueModID > 1000
		Begin
			TRUNCATE TABLE #PeptideModList
			Set @UniqueModID = -1
		End

		-- Populate #PeptideModList with the mass correction values for
		-- the isotopic modifications that apply to this sequence
		-- If the modification is an isotopic modification, then Affected_Atom will not be '-'
		--
		INSERT INTO #PeptideModList
		SELECT	T_Mod_Descriptors.Mass_Correction_Tag,
				T_Mod_Descriptors.Position,
				#MassCorrectionFactors.Monoisotopic_Mass,
				#MassCorrectionFactors.Affected_Atom
		FROM	T_Sequence INNER JOIN
				T_Mod_Descriptors ON T_Sequence.Seq_ID = T_Mod_Descriptors.Seq_ID LEFT OUTER JOIN
				#MassCorrectionFactors ON LTrim(RTrim(#MassCorrectionFactors.Mass_Correction_Tag)) = LTrim(RTrim(T_Mod_Descriptors.Mass_Correction_Tag))
		WHERE	T_Sequence.Seq_ID = @Seq_ID AND
				#MassCorrectionFactors.Affected_Atom <> '-'
		--
		SELECT @RowCountRemaining = @@rowcount, @myError = @@error
		--
		If @myError <> 0
		Begin
			Set @message = 'Error populating #PeptideModList table for Seq_ID ' + Convert(varchar(11), @Seq_ID) + ', ' + @orig_peptide
			Goto done
		End

		While @RowCountRemaining > 0
		Begin

			-- Obtain next modification from #PeptideModList
			SELECT	TOP 1
					@UniqueModID = UniqueModID,
					@MassCorrectionTag = Mass_Correction_Tag,
					@ModAffectedAtom = Affected_Atom,
					@MassCorrectionMass = Monoisotopic_Mass
			FROM #PeptideModList
			WHERE UniqueModID > @UniqueModID
			ORDER BY UniqueModID
			--
			SELECT @RowCountRemaining = @@RowCount

			If Not (@MassCorrectionMass = 0 Or @RowCountRemaining = 0)
			Begin

				Set @modFound = 0

				-- Examine @ModAffectedAtom
				If @ModAffectedAtom = 'C'
				Begin
					Set @mono_mass = @mono_mass + (@totalCountC * @MassCorrectionMass)
					Set @modFound = 1
				End

				If @ModAffectedAtom = 'H'
				Begin
					Set @mono_mass = @mono_mass + (@totalCountH * @MassCorrectionMass)
					Set @modFound = 1
				End

				If @ModAffectedAtom = 'N'
				Begin
					Set @mono_mass = @mono_mass + (@totalCountN * @MassCorrectionMass)
					Set @modFound = 1
				End

				If @ModAffectedAtom = 'O'
				Begin
					Set @mono_mass = @mono_mass + (@totalCountO * @MassCorrectionMass)
					Set @modFound = 1
				End

				If @ModAffectedAtom = 'S'
				Begin
					Set @mono_mass = @mono_mass + (@totalCountS * @MassCorrectionMass)
					Set @modFound = 1
				End

				If @modFound = 0
				Begin
					-- Invalid @ModAffectedAtom value

					Set @message = 'Unknown Affected Atom "' + @ModAffectedAtom + '" for Mass_Correction_Tag ' + @MassCorrectionTag
					Execute PostLogEntry 'Error', @message, 'CalculateMonoisotopicMass'

					Set @mono_mass = 0

					If (@AbortOnUnknownSymbolError <> 0)
					Begin
						Set @myError = 75005
						Goto done
					End
					Else
						Goto UpdateMass

				End
			End
		End



UpdateMass:

		---------------------------------------------------------
		--update mass tags table with the newly calculated mass
		---------------------------------------------------------
		UPDATE T_Sequence
		Set Monoisotopic_Mass = @mono_mass, Last_Affected = GetDate()
		WHERE Seq_ID = @Seq_ID

		--check for errors
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0
		Begin
			Set @message = 'Error in updating mass'
			Goto done
		End
		--success, so increment @PeptidesProcessedCount
		Set @PeptidesProcessedCount = @PeptidesProcessedCount + 1

		-- Since mass computation can take awhile, post an entry to T_Log_Entries every 25,000 peptides
		If @PeptidesProcessedCount % 2500 = 0
		Begin
			If @PeptidesProcessedCount % 25000 = 0
			Begin
				Set @Progress = '...Processing: ' + convert(varchar(9), @PeptidesProcessedCount)
				Execute PostLogEntry 'Progress', @Progress, 'CalculateMonoisotopicMass'
			End

			-- Validate that updating is enabled, abort if not enabled
			exec VerifyUpdateEnabled @CallingFunctionDescription = 'CalculateMonoisotopicMass', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
			If @UpdateEnabled = 0
				Goto Done
		End

		If @SequencesToProcess > 0
		Begin
			If @PeptidesProcessedCount >= @SequencesToProcess
				Set @continue = 0
		End

	End		--End of main While loop

Done:
	DROP INDEX #PeptideModList.#IX_PeptideModList_UniqueModID
	DROP TABLE #PeptideModList

	DROP INDEX #TMP_AA.#IX_TMP_AA_Symbol
	DROP TABLE #TMP_AA

	RETURN @PeptidesProcessedCount


GO
GRANT EXECUTE ON [dbo].[CalculateMonoisotopicMass] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CalculateMonoisotopicMass] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CalculateMonoisotopicMass] TO [MTS_DB_Lite] AS [dbo]
GO
