ALTER PROCEDURE ExtractPeptideMods
/****************************************************
**
**	Desc:	Parses text in column PeptideEx in T_Mass_Tags to determine the modifications present
**			Updates columns Peptide, Mod_Count, and Mod_Description
**
**
**	Auth:	mem
**	Date:	12/07/2016 mem - Initial version
**
*****************************************************/
(
	@infoOnly tinyint = 0,
	@message varchar(512) ='' output
) 
AS 
	Set NoCount On
	
	Declare @myError int
	Declare @myRowCount int
	
	Declare @seqID int
	Declare @peptideEx varchar(255)
	Declare @cleanSeq varchar(255)
	Declare @modCount smallint
	Declare @modDescription varchar(255)

	Declare @continue int
	Declare @seqsProcessed int

	Declare @peptideLength int
	Declare @charLoc int
	Declare @currentChar char
	Declare @currentResidue char
	Declare @residueLoc int
	Declare @modSpec varchar(255)

	---------------------------------------------------
	-- Clean up the inputs
	---------------------------------------------------
	
	Set @infoOnly = IsNull(@infoOnly, 1)
	
	Set @message= ''

	---------------------------------------------------
	-- Populate a temporary table with items to process
	---------------------------------------------------

	CREATE TABLE #Tmp_SeqsToProcess (
		Seq_ID int NOT NULL,
		PeptideEx varchar(255) NOT NULL,
		CleanSeq varchar(255) NULL,
		Mod_Count smallint null,					-- Number of mods
		Mod_Description varchar(255) null			-- Format: IodoAcet:7,IodoAcet:11
	)		
	
	CREATE UNIQUE CLUSTERED INDEX #IX_Tmp_SeqsToProcess ON #Tmp_SeqsToProcess (Seq_ID)
	
	CREATE TABLE #Tmp_ModDetails (
		Seq_ID int NOT NULL,
		Mod_Position smallint not null,
		Mod_Name varchar(64) not null		
	)
	
	CREATE CLUSTERED INDEX #IX_Tmp_ModDetails ON #Tmp_ModDetails (Seq_ID, Mod_Position)
	
	
	INSERT INTO #Tmp_SeqsToProcess (Seq_ID, PeptideEx, Mod_Count, Mod_Description)
	SELECT Mass_Tag_ID, PeptideEx, Mod_Count, Mod_Description
	FROM T_Mass_Tags
	WHERE IsNull(PeptideEx, '') <> ''
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	---------------------------------------------------
	-- Parse each item
	---------------------------------------------------
	
	Set @seqID = 0
	Set @continue = 1
	Set @seqsProcessed = 0
	
	While @continue = 1
	Begin -- <a>
		SELECT TOP 1 @seqID = Seq_ID,
			@peptideEx = PeptideEx
		FROM #Tmp_SeqsToProcess
		Where Seq_ID > @SeqID
		ORDER BY Seq_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
		Begin
			Set @continue = 0
		End
		Else
		Begin -- <b>
			If @peptideEx like '[a-z-].%.[a-z-]'
				Set @peptideEx = Substring(@peptideEx, 3, Len(@peptideEx) - 4)	
			Else
				Print 'Warning: unexpected peptide format: ' + @peptideEx
				
			If Not @peptideEx Like '%[[]%'
			Begin -- <c1>
				-- Peptide is not modified
				UPDATE #Tmp_SeqsToProcess
				SET CleanSeq = @peptideEx,
				    Mod_Count = 0,
				    Mod_Description = CASE
				                          WHEN IsNull(Mod_Description, '') = '' THEN ''
				                          WHEN Mod_Description NOT LIKE '[?][?][?]%' THEN '??? ' + Mod_Description
				                          ELSE Mod_Description
				                      END
				WHERE Seq_ID = @SeqID


			End -- </c1>
			Else
			Begin -- <c2>
				-- Peptide is modified
				
				Set @peptideLength = Len(@peptideEx)
				Set @charLoc = 1
				Set @residueLoc = 0
				Set @currentResidue = ''
				Set @cleanSeq = ''
				Set @modCount = 0
				Set @modDescription = ''
				
				While @charLoc <= @peptideLength
				Begin -- <d>
					Set @currentChar = Substring(@peptideEx, @charLoc, 1)
					
					IF @currentChar LIKE '[A-Z]'
					Begin -- <e1>
						Set @residueLoc = @residueLoc + 1
						Set @currentResidue = @currentChar
						Set @cleanSeq = @cleanSeq + @currentResidue
					End -- </e1>
					Else
					Begin -- <e2>
						IF @currentChar = '['
						Begin -- <f>
							-- Parse out the mod spec
							Set @modSpec = ''

							While @charLoc < @peptideLength AND @currentChar <> ']'
							Begin -- <g>
								Set @charLoc = @charLoc + 1
								Set @currentChar = Substring(@peptideEx, @charLoc, 1)

								IF @currentChar <> ']'
									Set @modSpec = @modSpec + @currentChar				
							End -- </g>

							INSERT INTO #Tmp_ModDetails (Seq_ID, Mod_Position, Mod_Name)
							Values (@seqID, @residueLoc, @modSpec)
							
							Set @modCount = @modCount + 1
							If Len(@modDescription) > 0
								Set @modDescription = @modDescription + ','
								
							Set @modDescription = @modDescription + @modSpec + ':' + Cast(@residueLoc as varchar(9))
							
						End -- </f>
					end -- </e2>

					Set @charLoc = @charLoc + 1
				End -- </d>

				UPDATE #Tmp_SeqsToProcess
				SET CleanSeq = @cleanSeq,
				    Mod_Count = @modCount,
				    Mod_Description = @modDescription
				WHERE Seq_ID = @SeqID
				
			End -- </c2>
			
			Set @seqsProcessed = @seqsProcessed + 1
		End
		
		
	End	
	
	If @infoOnly = 0
	Begin
		UPDATE Target
		SET Peptide = Src.CleanSeq,
		    Mod_Count = Src.Mod_Count,
		    Mod_Description = Src.Mod_Description
		FROM T_Mass_Tags Target
		     INNER JOIN #Tmp_SeqsToProcess AS Src
		       ON Target.Mass_Tag_ID = Src.Seq_ID
		WHERE NOT Src.CleanSeq IS NULL AND
		      (IsNull(Target.Peptide, '')         <> Src.CleanSeq OR
		       IsNull(Target.Mod_Count, '')       <> IsNull(Src.Mod_Count, '') OR
		       IsNull(Target.Mod_Description, '') <> IsNull(Src.Mod_Description, ''))
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		Print 'Updated ' + Cast(@myRowCount as varchar(9)) + ' rows in T_Mass_Tags'


		If Exists (Select * from #Tmp_ModDetails)
		Begin
			DELETE FROM T_Mass_Tag_Mod_Info
			WHERE Mass_Tag_ID IN ( SELECT Seq_ID FROM #Tmp_SeqsToProcess ) AND
			      NOT Mass_Tag_ID IN ( SELECT Seq_ID FROM #Tmp_ModDetails )


			INSERT INTO T_Mass_Tag_Mod_Info (Mass_Tag_ID, Mod_Name, Mod_Position)
			SELECT Seq_ID, Mod_Name, Mod_Position
			FROM #Tmp_ModDetails
			ORDER BY Seq_ID, Mod_Position
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			Print 'Added ' + Cast(@myRowCount as varchar(9)) + ' rows to T_Mass_Tag_Mod_Info'
			
		End
	End
	Else
	Begin
	
		SELECT *
		FROM #Tmp_SeqsToProcess
		ORDER BY Seq_ID

	
		SELECT Seq_ID, Mod_Name, Mod_Position
		FROM #Tmp_ModDetails
		ORDER BY Seq_ID, Mod_Position
	End
	
	
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:

	If @myError <> 0 and @infoOnly <> 0
		Print @Message
 
