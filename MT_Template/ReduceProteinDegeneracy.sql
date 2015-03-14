/****** Object:  StoredProcedure [dbo].[ReduceProteinDegeneracy] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE ReduceProteinDegeneracy
/****************************************************	
**  Desc:	Processes a table of 
**
**		The calling procedure must create table #TmpAMTtoProteinMap
**
**		CREATE TABLE #TmpAMTtoProteinMap (
**			Mass_Tag_ID int not null,
**			Ref_ID int not null,
**			Valid smallint not null
**		)
**
**	CREATE CLUSTERED INDEX #IX_TmpAMTtoProteinMap ON #TmpAMTtoProteinMap(Mass_Tag_ID, Ref_ID)
**
**  Return values: 0 if success, otherwise, error code
**
**  Auth:	mem
**	Date:	11/01/2011
**
****************************************************/
(	
	@ProteinDegeneracyMode tinyint=1,				-- 0=Keep all degenerate proteins; 1=Iteratively remove entries from #TmpAMTtoProteinMap by favoring the protein with the highest sequence coverage; 2=Iteratively remove entries from #TmpAMTtoProteinMap by favoring the protein with the most identified peptides
	@Iterations int = 0 output,
	@message varchar(512) = '' output,
	@DebugProteinCoverageData tinyint = 0,
	@DebugMassTagID int = 0
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @continue tinyint
	
	-----------------------------------------------------------
	-- Validate the inputs and initialize output variables
	-----------------------------------------------------------
	--
	Set @Iterations = 0
	Set @ProteinDegeneracyMode = IsNull(@ProteinDegeneracyMode, 1)
	Set @message = ''
	
	-----------------------------------------------------------
	-- Make sure all entries start off with valid = 1
	-----------------------------------------------------------
	--
	UPDATE #TmpAMTtoProteinMap
	Set Valid = 1
	WHERE Valid < 1
	
	If @ProteinDegeneracyMode > 0
	Begin -- <a>
		
		If @ProteinDegeneracyMode = 1
		Begin -- <b>
			-- Compute sequence coverage for each protein
			
			CREATE TABLE #TmpDegeneracyProteinCoverage (
				Ref_ID int NOT NULL,
				Protein_Sequence varchar(8000) NOT NULL,
				Protein_Coverage_Residue_Count int NULL,
				Protein_Coverage_Fraction real NULL,
				Process tinyint not NULL
			)
			
			CREATE UNIQUE CLUSTERED INDEX #IX__TmpDegeneracyProteinCoverage ON #TmpDegeneracyProteinCoverage ([Ref_ID])
		
			INSERT INTO #TmpDegeneracyProteinCoverage( Ref_ID,
			                                           Protein_Sequence,
			                                           Process )
			SELECT #TmpAMTtoProteinMap.Ref_ID,
			       LOWER(Convert(varchar(8000), T_Proteins.Protein_Sequence)),				-- Convert the protein sequence to lowercase
			       1 AS Process
			FROM #TmpAMTtoProteinMap
			     INNER JOIN T_Proteins
			       ON #TmpAMTtoProteinMap.Ref_ID = T_Proteins.Ref_ID
			WHERE NOT T_Proteins.Protein_Sequence IS NULL
			GROUP BY #TmpAMTtoProteinMap.Ref_ID, LOWER(Convert(varchar(8000), T_Proteins.Protein_Sequence))
			--	
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			If @myError <> 0 
			Begin
				Set @message = 'Error while populating the #TmpDegeneracyProteinCoverage temporary table'
				Set @myError = 138
				Goto Done
			End -- </b>

			Exec @myError = ReduceProteinDegeneracyUpdateProteinCoverage @ComputationMode=0
			
			If @DebugProteinCoverageData <> 0
			Begin
				SELECT *
				FROM #TmpDegeneracyProteinCoverage
				ORDER BY Process Desc, Ref_ID
			End

		End
		
		Set @continue = 1
		While @continue = 1
		Begin -- <c>

			If @DebugMassTagID > 0
			Begin -- <d1>
				If @ProteinDegeneracyMode = 1
				Begin
					SELECT PM.Valid,
					       PM.Ref_ID,
					       PC.Protein_Coverage_Fraction
					FROM #TmpAMTtoProteinMap PM
					     INNER JOIN #TmpDegeneracyProteinCoverage PC
					       ON PM.Ref_ID = PC.Ref_ID
					WHERE PM.Mass_Tag_ID = @DebugMassTagID
					ORDER BY PM.Ref_ID
				End

				If @ProteinDegeneracyMode = 2
				Begin
					SELECT PM.Valid,
					       PM.Ref_ID,
					       ISNull(ProtQ.PeptideCount, 0) AS PeptideCount
					FROM #TmpAMTtoProteinMap PM
					     LEFT OUTER JOIN ( SELECT Ref_ID,
					                              COUNT(*) AS PeptideCount
					                       FROM #TmpAMTtoProteinMap
					                       WHERE Valid > 0
					                       GROUP BY Ref_ID ) ProtQ
					       ON PM.Ref_ID = ProtQ.Ref_ID
					WHERE PM.Mass_Tag_ID = @DebugMassTagID
					ORDER BY PM.Ref_ID
				End

			End -- </d1>		
				
			If @ProteinDegeneracyMode = 1
			Begin -- <d2>
				-- On each iteration, for each peptide in #TmpAMTtoProteinMap that has multiple Ref_IDs
				-- Change Valid to -1 for the Ref_ID with the lowest sequence coverage
				-- We set it to -1 to speed up SP ReduceProteinDegeneracyUpdateProteinCoverage so that it only processes peptide/protein relationships that have been newly marked invalid
				--
				UPDATE APM
				SET Valid = -1
				FROM #TmpAMTtoProteinMap APM
				     INNER JOIN ( SELECT PM.Mass_Tag_ID,
				                         PM.Ref_ID,
				                         ROW_NUMBER() OVER ( PARTITION BY PM.Mass_Tag_ID 
				                                             ORDER BY ProtQ.Protein_Coverage_Fraction ) AS CoverageRank
				                  FROM #TmpAMTtoProteinMap PM
				                       INNER JOIN ( SELECT Ref_ID,
				                                           IsNull(Protein_Coverage_Fraction, 0) AS Protein_Coverage_Fraction
				                                    FROM #TmpDegeneracyProteinCoverage 
				                                  ) ProtQ
				                         ON PM.Ref_ID = ProtQ.Ref_ID
				                       INNER JOIN ( SELECT Mass_Tag_ID
				                                    FROM #TmpAMTtoProteinMap
				                                    WHERE Valid > 0
				                                    GROUP BY Mass_Tag_ID
				                                    HAVING COUNT(*) > 1 
				                                  ) MultiCountQ
				                         ON PM.Mass_Tag_ID = MultiCountQ.Mass_Tag_ID
				                  WHERE PM.Valid > 0 
				                ) FilterQ
				       ON APM.Mass_Tag_ID = FilterQ.Mass_Tag_ID AND
				          APM.Ref_ID = FilterQ.Ref_ID
				WHERE FilterQ.CoverageRank = 1
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount
				
			End -- </d2>

			If @ProteinDegeneracyMode = 2
			Begin -- <d3>
				-- On each iteration, for each peptide in #TmpAMTtoProteinMap that has multiple Ref_IDs
				-- Change Valid to 0 for the Ref_ID with the fewest peptides that still have Valid=1
				--
				UPDATE APM
				SET Valid = 0
				FROM #TmpAMTtoProteinMap APM
				     INNER JOIN ( SELECT PM.Mass_Tag_ID,
				                         PM.Ref_ID,
				                         ROW_NUMBER() OVER ( PARTITION BY PM.Mass_Tag_ID 
				                                             ORDER BY ProtQ.PeptideCount ) AS CountRank
				                  FROM #TmpAMTtoProteinMap PM
				                       INNER JOIN ( SELECT Ref_ID,
				                                           COUNT(*) AS PeptideCount
				                                    FROM #TmpAMTtoProteinMap
				                                    WHERE Valid > 0
				                                    GROUP BY Ref_ID 
				                                  ) ProtQ
				                         ON PM.Ref_ID = ProtQ.Ref_ID
				                       INNER JOIN ( SELECT Mass_Tag_ID
				                                    FROM #TmpAMTtoProteinMap
				                                    WHERE Valid > 0
				                                    GROUP BY Mass_Tag_ID
				                                    HAVING COUNT(*) > 1 
				                                  ) MultiCountQ
				                         ON PM.Mass_Tag_ID = MultiCountQ.Mass_Tag_ID
				                  WHERE PM.Valid > 0 
				                ) FilterQ
				       ON APM.Mass_Tag_ID = FilterQ.Mass_Tag_ID AND
				          APM.Ref_ID = FilterQ.Ref_ID
				WHERE FilterQ.CountRank = 1
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount
				
			End -- </d3>
						
			If @myRowCount = 0
				Set @continue = 0
			Else
			Begin
				Set @Iterations = @Iterations + 1
				
				If @ProteinDegeneracyMode = 1
				Begin
					-- Recompute Sequence Coverage (only process proteins with peptides that have Valid=-1)
					
					Exec @myError = ReduceProteinDegeneracyUpdateProteinCoverage @ComputationMode=1
					
					-- Change valid to 0 for peptides where valid = 0
					UPDATE #TmpAMTtoProteinMap
					Set Valid = 0
					WHERE Valid = -1
					
					If @DebugProteinCoverageData <> 0
					Begin
						SELECT *
						FROM #TmpDegeneracyProteinCoverage
						ORDER BY Process Desc, Ref_ID
					End
				End
			End
			
		End -- </c>
		
	End -- </a>
	
Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[ReduceProteinDegeneracy] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ReduceProteinDegeneracy] TO [MTS_DB_Lite] AS [dbo]
GO
