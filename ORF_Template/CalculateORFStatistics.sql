SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CalculateORFStatistics]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[CalculateORFStatistics]
GO


CREATE PROCEDURE dbo.CalculateORFStatistics
/****************************************************
**
**	Desc: Calculates ORF average mass, monoisotopic mass, 
**        molecular formula, amino acid count, and amino acid formula
**		  for the ORF's in T_ORF that do not yet have these values
**
**	Return values: 0 if successful, not zero if failure
**
**	Parameters:
**	
**  Output:
**		@message - '' if successful, otherwise a message about
**			what went wrong
**		@count - the number of rows for which the mass 
**			was successfully calculated
**
**		Auth: mem (based on CalculateMonoisotopicMass, written by kal)
**		Date: 2/20/2004
**
**		Updated: 2/21/2004 by mem: Re-ordered code slightly when ORF sequence symbol is not found in #TMP_AA
**				 2/23/2004 by mem: Now updating the Date_Modified column in T_ORF when saving the statistics
**				 2/28/2004 by mem: Now posting message to T_Log_Entries if an unknown amino acid symbol is found
**				 4/15/2005 by mem: Added symbol 'U' for Selenocysteine
**    
*****************************************************/
	(
		@message varchar(255) = '' output,
		@count int = 0 output,						-- number of ORFs for which monoisotopic mass was calculated
		@RecomputeAll tinyint = 0,					-- When 1, recomputes masses for all ORFs; when 0, only computes if monoisotopic_mass, average_mass, or amino_acid_count are currently Null
		@AbortOnUnknownSymbolError tinyint = 0		-- When 1, then aborts calculations if an unknown symbol is found
	)
AS
	SET NOCOUNT ON

	set @message = ''
	set @count = 0

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	--used for storing information from each table row
	declare @ORF_ID int
	set @ORF_ID = -100000000
	
	-- Since the ORF sequences are stored in text variables, we can only obtain 8000 characters at a time
	-- Consequently, we'll grab at most 24000 characters, allowing for an ORF weighing at most roughly 2,600,000 Da
	declare @intCurrentSeqIndex tinyint
	declare @CurrentSeq varchar(8000),
			@sequence1 varchar(8000),
			@sequence2 varchar(8000),
			@sequence3 varchar(8000)

	--the various stats for the formula
	declare @mono_Mass float,
			@avg_Mass float,
			@AACount int,			-- number of amino acids (aka residues)
			@ORFAminoAcidFormula varchar(512),
			@ORFMolecularFormula varchar(64)
	
	--used while looping through the ORF's, adding the mass of each amino acid to the total
	declare @currentAA char,		--current amino acid
			@currentAAMonoMass float,
			@currentAAAvgMass float
	
	--counts of atoms for current amino acid
	declare @countC int,
			@countH int,
			@countN int,
			@countO int,
			@countS int

	--counts of atoms for entire ORF
	declare @totalCountC int,
			@totalCountH int,
			@totalCountN int,
			@totalCountO int,
			@totalCountS int

	-- tells whether main loop has been completed
	declare @done int
	set @done = 1

	--------------------------------------------
	--Create temporary amino acid table
	--------------------------------------------
	CREATE TABLE #TMP_AA (
		[Symbol] [varchar] (16)  NOT NULL ,
		[Abbreviation] [varchar] (50)  NOT NULL ,
		[C_Count] [int] NOT NULL,
		[H_Count] [int] NOT NULL,
		[N_Count] [int] NOT NULL,
		[O_Count] [int] NOT NULL,
		[S_Count] [int] NOT NULL,
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
	'U','Sec',3,5,1,1,0,150.03794,150.95363						' Selenocysteine
	'W','Trp',11,10,2,1,0,186.214752607545,186.079306125641
	'Y','Tyr',9,9,1,2,0,163.177208595079,163.063322782516
	'V','Val',5,9,1,1,0,99.1334102970637,99.0684087276459
	'Q','Gln',5,8,2,2,0,128.13152991695,128.058570861816
	'X','unknown',5,8,2,2,0,128.13152991695,128.058570861816
	'H2O','Water(ORF Ends)',0,2,0,1,0,18.01528,18.010563
	*/
	INSERT INTO #TMP_AA
	VALUES ('A','Ala',3,5,1,1,0,71.0792940261929,71.0371100902557)
	INSERT INTO #TMP_AA
	VALUES ('R','Arg',6,12,4,1,0,156.188618505844,156.101100921631)
	INSERT INTO #TMP_AA
	VALUES ('N','Asn',4,6,2,2,0,114.104471781515,114.042921543121)
	INSERT INTO #TMP_AA
	VALUES ('D','Asp',4,5,1,3,0,115.089141736421,115.026938199997)
	INSERT INTO #TMP_AA
	VALUES ('C','Cys',3,5,1,1,1,103.143682753682,103.009180784225)
	INSERT INTO #TMP_AA
	VALUES ('E','Glu',5,7,1,3,0,129.116199871857,129.042587518692)
	INSERT INTO #TMP_AA
	VALUES ('O','Orn',5,10,2,1,0,114.148110705429,114.079306125641)
	INSERT INTO #TMP_AA
	VALUES ('B','Asn/Asp',4,6,2,2,0,114.104471781515,114.042921543121)
	INSERT INTO #TMP_AA
	VALUES ('G','Gly',2,3,1,1,0,57.0522358907575,57.0214607715607)
	INSERT INTO #TMP_AA
	VALUES ('H','His',6,7,3,1,0,137.142015793981,137.058904886246)
	INSERT INTO #TMP_AA
	VALUES ('I','Ile',6,11,1,1,0,113.160468432499,113.084058046341)
	INSERT INTO #TMP_AA
	VALUES ('L','Leu',6,11,1,1,0,113.160468432499,113.084058046341)
	INSERT INTO #TMP_AA
	VALUES ('K','Lys',6,12,2,1,0,128.175168840864,128.094955444336)
	INSERT INTO #TMP_AA
	VALUES ('M','Met',5,9,1,1,1,131.197799024553,131.040479421616)
	INSERT INTO #TMP_AA
	VALUES ('F','Phe',9,9,1,1,0,147.177838231808,147.068408727646)
	INSERT INTO #TMP_AA
	VALUES ('Z','Gln/Glu',5,8,2,2,0,128.13152991695,128.058570861816)
	INSERT INTO #TMP_AA
	VALUES ('P','Pro',5,7,1,1,0,97.1174591453144,97.0527594089508)
	INSERT INTO #TMP_AA
	VALUES ('S','Ser',3,5,1,2,0,87.0786643894641,87.0320241451263)
	INSERT INTO #TMP_AA
	VALUES ('T','Thr',4,7,1,2,0,101.1057225249,101.047673463821)
	INSERT INTO #TMP_AA
	VALUES ('U','Sec',3,5,1,1,0,150.03794,150.95363)
	INSERT INTO #TMP_AA
	VALUES ('W','Trp',11,10,2,1,0,186.214752607545,186.079306125641)
	INSERT INTO #TMP_AA
	VALUES ('Y','Tyr',9,9,1,2,0,163.177208595079,163.063322782516)
	INSERT INTO #TMP_AA
	VALUES ('V','Val',5,9,1,1,0,99.1334102970637,99.0684087276459)
	INSERT INTO #TMP_AA
	VALUES ('Q','Gln',5,8,2,2,0,128.13152991695,128.058570861816)
	INSERT INTO #TMP_AA
	VALUES ('X','unknown',5,8,2,2,0,128.13152991695,128.058570861816)
	INSERT INTO #TMP_AA
	VALUES ('H2O','Water(ORF Ends)',0,2,0,1,0,18.01528,18.0105633)


	SELECT @myRowCount = @@rowcount, @myError = @@error

	if @myError <> 0
	begin
		Set @message = 'Failure in setting up temporary amino acid table'
		goto done
	end


	--------------------------------------------
	--Create temporary table to hold the amino acid occurrence counts for each ORF
	--------------------------------------------
	CREATE TABLE #TMP_AACount (
		[Symbol] [varchar] (16)  NOT NULL ,
		[AACount] int  NOT NULL
	)

	CREATE UNIQUE INDEX #IX_TMP_AACount_Symbol ON #TMP_AACount (Symbol ASC)

	-- Populate TMP_AACount
	INSERT INTO #TMP_AACount
	SELECT Symbol, 0
	FROM #TMP_AA
	ORDER BY Symbol

	-----------------------------------------------
	--Loop through each entry in T_ORF table, computing various stats if possible
	-----------------------------------------------
	while @done > 0
	begin
		set @sequence1 = ''
		set @sequence2 = ''
		set @sequence3 = ''
		set @CurrentAA = ' '
		
		If @RecomputeAll <> 0
			--read data for one ORF into local variables
			SELECT TOP 1
					@ORF_ID = ORF_ID,
					@sequence1 = Substring(Protein_Sequence,1,8000),
					@sequence2 = Substring(Protein_Sequence,8001,8000),
					@sequence3 = Substring(Protein_Sequence,16001,8000)
			FROM T_ORF
			WHERE ORF_ID > @ORF_ID
			ORDER BY ORF_ID ASC
		Else
			--read data for one ORF into local variables
			SELECT TOP 1
					@ORF_ID = ORF_ID,
					@sequence1 = Substring(Protein_Sequence,1,8000),
					@sequence2 = Substring(Protein_Sequence,8001,8000),
					@sequence3 = Substring(Protein_Sequence,16001,8000)
			FROM T_ORF
			WHERE ORF_ID > @ORF_ID AND 
				(Monoisotopic_Mass Is Null OR Average_Mass Is Null OR Amino_Acid_Count Is Null)
			ORDER BY ORF_ID ASC
		
		--check for errors in loading
		SELECT @myError = @@error, @myRowCount = @@rowcount
		if @myError <> 0
		begin
			set @message = 'Error in reading ORF info from table.'
			goto done
		end
		if @myRowCount = 0 -- we're done
		begin
			set @message = ''
			set @myError = 0
			goto done
		end
		set @done = @myRowCount

		---------------------------------------
		--compute statistics
		---------------------------------------
		set @mono_mass = 0
		Set @avg_Mass = 0
		set @totalCountC = 0
		set @totalCountH = 0
		set @totalCountN = 0
		set @totalCountO = 0
		set @totalCountS = 0
		set @AACount = 0
		
		UPDATE #TMP_AACount
		SET AACount = 0
		
		--------------------------------------------
		--loop through characters in @sequence1, then @sequence2, then @sequence3
		--incrementing totals for each character (i.e. each residue)
		--------------------------------------------
		Set @intCurrentSeqIndex = 1
		while @intCurrentSeqIndex <=3
		begin
			if (@intCurrentSeqIndex = 1)
				Set @CurrentSeq = @sequence1
			else
				if (@intCurrentSeqIndex = 2)
					Set @CurrentSeq = @sequence2
				else
					Set @CurrentSeq = @sequence3

			while len(@CurrentSeq) > 0
			begin
				--extract first character from ORF string, then set the ORF
				--to the remainder
				set @currentAA = substring(@CurrentSeq, 1, 1)
				set @CurrentSeq = substring(@CurrentSeq, 2, len(@CurrentSeq) - 1)
				
				--lookup mass for this amino acid
				SELECT  @currentAAMonoMass = Monoisotopic_Mass,
						@currentAAAvgMass = Average_Mass,
						@countC = C_Count,
						@countH = H_Count,
						@countN = N_Count,
						@countO = O_Count,
						@countS = S_Count
				FROM #TMP_AA
				WHERE Symbol = @currentAA
				
				--check for errors
				SELECT @myError = @@error, @myRowCount = @@rowcount
				if @myError <> 0
				begin
					set @message = 'Error in looking up mass in temp table for symbol ' + @currentAA
					goto done
				end
				
				if @myRowCount = 0
				 begin
					-- Symbol not found; update @message and possibly abort processing
					set @message = 'Unknown symbol ' + @currentAA + ' for ORF_ID ' + LTRIM(RTRIM(STR(@ORF_ID)))
					if (@AbortOnUnknownSymbolError <> 0)
					 begin
						set @myError = 75005
						Goto done
					 end
					else
						Execute PostLogEntry 'Error', @message, 'CalculateORFStatistics'
				 end
				else
				 begin
					--add mass of amino acid to current total
					set @mono_mass = @mono_mass + @currentAAMonoMass
					set @avg_mass = @avg_mass + @currentAAAvgMass
					set @totalCountC = @totalCountC + @countC
					set @totalCountH = @totalCountH + @countH
					set @totalCountN = @totalCountN + @countN
					set @totalCountO = @totalCountO + @countO
					set @totalCountS = @totalCountS + @countS
	
					Set @AACount = @AACount + 1
					
					UPDATE #TMP_AACount
					SET AACount = AACount + 1
					WHERE Symbol = @currentAA
				 end
				
			end --end of looping through ORF sequence
				
			Set @intCurrentSeqIndex = @intCurrentSeqIndex + 1
		end
		
		
		--add in mass of water
		SELECT  @currentAAMonoMass = Monoisotopic_Mass,
				@currentAAAvgMass = Average_Mass,
					@countC = C_Count,
					@countH = H_Count,
					@countN = N_Count,
					@countO = O_Count,
					@countS = S_Count
		FROM #TMP_AA
		WHERE Symbol = 'H2O'
		
		set @mono_mass = @mono_mass + @currentAAMonoMass
		set @avg_mass = @avg_mass + @currentAAAvgMass
		set @totalCountC = @totalCountC + @countC
		set @totalCountH = @totalCountH + @countH
		set @totalCountN = @totalCountN + @countN
		set @totalCountO = @totalCountO + @countO
		set @totalCountS = @totalCountS + @countS
		
		-- Construct ORF Molecular Formula; for example C269 H455 N71 O82 S2
		Set @ORFMolecularFormula = ''
		Set @ORFMolecularFormula = @ORFMolecularFormula + 'C' + LTrim(RTrim(Convert(varchar(11), @totalCountC))) + ' '
		Set @ORFMolecularFormula = @ORFMolecularFormula + 'H' + LTrim(RTrim(Convert(varchar(11), @totalCountH))) + ' '
		Set @ORFMolecularFormula = @ORFMolecularFormula + 'N' + LTrim(RTrim(Convert(varchar(11), @totalCountN))) + ' '
		Set @ORFMolecularFormula = @ORFMolecularFormula + 'O' + LTrim(RTrim(Convert(varchar(11), @totalCountO))) + ' '
		Set @ORFMolecularFormula = @ORFMolecularFormula + 'S' + LTrim(RTrim(Convert(varchar(11), @totalCountS)))

		-- Construct the Amino Acid Formula; for example A8 D2 E6 F2 G2 H1 K6 L13 M2 N2 R2 S2 T6 V1
		Set @ORFAminoAcidFormula = ''
		SELECT @ORFAminoAcidFormula = @ORFAminoAcidFormula + Symbol + LTrim(RTrim(Convert(varchar(11), AACount))) + ' '
		FROM #TMP_AACount
		WHERE AACount > 0
		ORDER BY Symbol

		
		---------------------------------------------------------	
		--update ORF table with the new stats
		---------------------------------------------------------
		UPDATE T_ORF
		SET Monoisotopic_Mass = @mono_mass,
			Average_Mass = @avg_mass,
			Amino_Acid_Count = @AACount,
			Molecular_Formula = @ORFMolecularFormula,
			Amino_Acid_Formula = LTrim(RTrim(@ORFAminoAcidFormula)),
			Date_Modified = GetDate()
		WHERE ORF_ID = @ORF_ID

		
		--check for errors
		SELECT @myError = @@error, @myRowCount = @@rowcount
		if @myError <> 0 
		begin
			set @message = 'Error in updating mass'
			goto done
		end

		--success, so increment @count
		set @count = @count + 1
		
	end		--end of main while loop

done:

	DROP INDEX #Tmp_AACount.#IX_TMP_AACount_Symbol
	DROP TABLE #Tmp_AACount
	
	DROP INDEX #TMP_AA.#IX_TMP_AA_Symbol
	DROP TABLE #TMP_AA

	If @Count > 0
		SELECT 'Updated ORF statistics for ' + convert(varchar(9), @Count) + ' ORFs'
	Else
		SELECT 'No ORFs were found that needed to be updated'
		
	RETURN @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

