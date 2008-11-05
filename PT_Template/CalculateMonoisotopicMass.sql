/****** Object:  StoredProcedure [dbo].[CalculateMonoisotopicMass] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE dbo.CalculateMonoisotopicMass
/****************************************************
**
**	Desc: Calculates the monoisotopic mass for the peptides
**		in T_Sequence
**
**	Returns the number of rows for which the mass was successfully calculated
**
**	Parameters:
**	
**  Output:
**		@message - '' if successful, otherwise a message about
**			what went wrong
**
**		Auth: mem (modified version of CalculateMonoisotopicMass written by kal)
**		Date: 03/25/2004
**
**		Updated: 03/27/2004 mem - Changed logic to store mass of 0 if an unknown symbol is found and it is not a letter
**				 04/14/2005 mem - Ported for use with Peptide DB Schema version 2, synchronizing to the mass calculation SP in the PMT Tag DBs
**    
*****************************************************/
	(
		@message varchar(255) = '' output,
		@RecomputeAll tinyint = 0,					-- When 1, recomputes masses for all peptides; when 0, only computes if the mass is currently Null
		@AbortOnUnknownSymbolError tinyint = 0		-- When 1, then aborts calculations if an unknown symbol is found
	)
AS
	Set NOCOUNT ON

	Set @message = ''

	Declare @PeptidesProcessedCount int
	Declare @myRowCount int
	Declare @myError int
	
	Set @PeptidesProcessedCount = 0
	Set @myRowCount = 0
	Set @myError = 0

	Declare @Progress varchar(255)
	Declare @result int
	
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
	FROM MT_Main..V_DMS_Residues
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


	---------------------------------------------------
	-- create temporary table to hold mod set members
	---------------------------------------------------

	CREATE TABLE #TModDescriptors (
		[Mass_Tag_ID] [int] NULL,					-- Seq_ID is stored here
		[Mass_Correction_Tag] [char] (8) NULL,
		[Position] [int] NULL,
		[UniqueModID] [int] IDENTITY
	)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error trying to create #TModDescriptors temporary table'
		goto Done
	end


	CREATE UNIQUE INDEX #IX_ModDescriptors_UniqueModID ON #TModDescriptors (UniqueModID)


	-- Variables for processing Modifications
	Declare @modCount int
	Declare @modDescription varchar(2048)
	
	Declare @modCountFoundInDescription int
	Declare @modCountValid int


	CREATE TABLE #MassCorrectionFactors (
		[Mass_Correction_ID] [int] NOT NULL ,
		[Mass_Correction_Tag] [char] (8) NOT NULL ,
		[Monoisotopic_Mass] [float] NOT NULL ,
		[Affected_Atom] [char] (1) NOT NULL
	)
	
	Declare @MassCorrectionTableInitialized tinyint
	Set @MassCorrectionTableInitialized = 0


	Declare @UniqueModID int
	Set @UniqueModID = -1


	Set @message = 'Monoisotopic mass calculations starting'
	Execute PostLogEntry 'Normal', @message, 'CalculateMonoisotopicMass'
	
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
					@orig_peptide = dbo.T_Sequence.Clean_Sequence,
					@modCount = Mod_Count,
					@modDescription = Mod_Description
			FROM dbo.T_Sequence 
			WHERE Seq_ID > @Seq_ID
			ORDER BY Seq_ID ASC
		Else
			--read data for one peptide into local variables
			SELECT TOP 1
					@Seq_ID = Seq_ID,
					@peptide = dbo.T_Sequence.Clean_Sequence, 
					@orig_peptide = dbo.T_Sequence.Clean_Sequence,
					@modCount = Mod_Count,
					@modDescription = Mod_Description
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
		
		If @MassCorrectionTableInitialized = 0
		Begin
			-- Create a temporary table version of V_DMS_Monoisotopic_Masss
			-- Doing this here, rather than above, since we only need to cache this
			-- information if one or more sequences needs to have its mass calculated
			INSERT INTO #MassCorrectionFactors
			SELECT Mass_Correction_ID, Mass_Correction_Tag,
					IsNull(Monoisotopic_Mass_Correction, 0),
					IsNull(Affected_Atom, '-')
			FROM MT_Main..V_DMS_Mass_Correction_Factors
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			If @myError <> 0 or @myRowCount = 0
			Begin
				Set @message = 'Error populating #MassCorrectionFactors temporary table'
				Goto done
			End
			
			Set @MassCorrectionTableInitialized = 1
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
				Set @message = 'Unknown symbol ' + @currentAA + ' for Seq_ID ' + Convert(varchar(11), @Seq_ID)
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
		

		-----------------------------------------------------------
		-- Now deal with modifications by parsing @modDescription
		-- Note that both positional and non-positional mods are
		--  notated in @modDescription
		-----------------------------------------------------------

		if @modDescription <> ''
		Begin
			-- Note: Rather than using Truncate Table after every sequence to clear #TModDescriptors, it is
			--       more efficient to continually add new modifications to the table as peptides are processed
			--       and only Truncate the table every 1000 sequences (arbitrary value)
			-- Continual use of Truncate Table actually slows down this procedure due to drastically increased disk activity

			If @UniqueModID > 1000
			Begin
				TRUNCATE TABLE #TModDescriptors
				Set @UniqueModID = -1
			End

			-- unroll mod description into temporary table (#TModDescriptors)
			--
			Set @result = 0
			exec @result = UnrollModDescription
								@Seq_ID,
								@modDescription,
								@message output
			--
			if @result <> 0
			begin
				Set @message = 'Error unrolling mod description ' + @modDescription + ' for Seq_ID ' + Convert(varchar(11), @Seq_ID)

				if @result = 90000
					Set @message = @message + '; mod not in the expected form'
					
				Execute PostLogEntry 'Error', @message, 'CalculateMonoisotopicMass'
				
				If (@AbortOnUnknownSymbolError <> 0)
				Begin
					Set @myError = 75006
					Goto done
				End
			end
			
			Set @modCountFoundInDescription = 0
			--
			SELECT	@modCountFoundInDescription = Count(Mass_Tag_ID), @UniqueModID = IsNull(Max(UniqueModID), @UniqueModID)
			FROM	#TModDescriptors
			WHERE	Mass_Tag_ID = @Seq_ID
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			
			
			If @modCountFoundInDescription = 0
			Begin
				Set @message = 'No mods found in ' + @modDescription + ' for Seq_ID ' + Convert(varchar(11), @Seq_ID) + ' although Mod_Count in T_Mass_Tags is ' + Convert(varchar(11), @modCount)
				Execute PostLogEntry 'Error', @message, 'CalculateMonoisotopicMass'

				If (@AbortOnUnknownSymbolError <> 0)
				Begin
					Set @myError = 75007
					Goto done
				End
			End
			Else
			Begin

				-- We can use a simple Select query to add all of the modification masses
				-- to @mono_Mass
				--
				SELECT	@mono_mass = @mono_mass + MCF.Monoisotopic_Mass
				FROM	#TModDescriptors INNER JOIN #MassCorrectionFactors AS MCF ON
						#TModDescriptors.Mass_Correction_Tag = MCF.Mass_Correction_Tag
				WHERE	#TModDescriptors.Mass_Tag_ID = @Seq_ID
				--
				SELECT @modCountValid = @@rowcount, @myError = @@error
				--
				If @myError <> 0
				Begin
					Set @message = 'Error updating the mass to include modification masses for Seq_ID ' + Convert(varchar(11), @Seq_ID) + ', ' + @orig_peptide
					Goto done
				End

				If @modCountValid = 0
				Begin
					Set @message = 'No valid mods found in ' + @modDescription + ' for Seq_ID ' + Convert(varchar(11), @Seq_ID) + ' although Mod_Count in T_Mass_Tags is ' + Convert(varchar(11), @modCount)
					Execute PostLogEntry 'Error', @message, 'CalculateMonoisotopicMass'

					If (@AbortOnUnknownSymbolError <> 0)
					Begin
						Set @myError = 75008
						Goto done
					End
				End
				Else
				Begin
					If @modCountValid <> @modCount
					Begin
						Set @message = 'Found ' + Convert(varchar(11), @modCountValid) + ' valid mods in ' + @modDescription + ' for Seq_ID ' + Convert(varchar(11), @Seq_ID) + ' although Mod_Count in T_Mass_Tags is ' + Convert(varchar(11), @modCount)
						Execute PostLogEntry 'Error', @message, 'CalculateMonoisotopicMass'

						If (@AbortOnUnknownSymbolError <> 0)
						Begin
							Set @myError = 75009
							Goto done
						End
					End
				End
			End
		End
		

UpdateMass:
					
		---------------------------------------------------------	
		--update mass tags table with the newly calculated mass
		---------------------------------------------------------
		UPDATE T_Sequence
		Set Monoisotopic_Mass = @mono_mass
		WHERE Seq_ID = @Seq_ID
		
		--check for errors
		SELECT @myError = @@error, @myRowCount = @@rowcount
		If @myError <> 0 
		Begin
			Set @message = 'Error in updating mass'
			Goto done
		End
		--success, so increment @PeptidesProcessedCount
		Set @PeptidesProcessedCount = @PeptidesProcessedCount + 1
		
		-- Since mass computation can take awhile, post an entry to T_Log_Entries every 10,000 peptides
		If @PeptidesProcessedCount % 25000 = 0
		Begin
			Set @Progress = '...Processing: ' + convert(varchar(9), @PeptidesProcessedCount)
			Execute PostLogEntry 'Progress', @Progress, 'CalculateMonoisotopicMass'
		End
		
		
	End		--End of main While loop

done:
	DROP INDEX #TModDescriptors.#IX_ModDescriptors_UniqueModID
	DROP TABLE #TModDescriptors

	DROP INDEX #TMP_AA.#IX_TMP_AA_Symbol
	DROP TABLE #TMP_AA

	if @myError = 0
		Execute PostLogEntry 'Error', @message, 'CalculateMonoisotopicMass'
	else
	begin
		Set @message = 'Monoisotopic mass calculations completed: ' + convert(varchar(11), @PeptidesProcessedCount) + ' sequences processed'
		Execute PostLogEntry 'Normal', @message, 'CalculateMonoisotopicMass'
	end
		
	RETURN @PeptidesProcessedCount

GO
GRANT VIEW DEFINITION ON [dbo].[CalculateMonoisotopicMass] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[CalculateMonoisotopicMass] TO [MTS_DB_Lite]
GO
