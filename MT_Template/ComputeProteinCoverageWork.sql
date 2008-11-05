/****** Object:  StoredProcedure [dbo].[ComputeProteinCoverageWork] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ComputeProteinCoverageWork
/****************************************************
**
**	Desc:	Populates the T_Protein_Coverage table with
**			protein coverage stats for a given @PMTQualityScoreMinimum value
**
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	09/22/2004
**			05/20/2005 mem - Updated logic to exclude proteins whose only entries in T_Mass_Tags have Internal_Standard_Only <> 0
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**			10/06/2006 mem - Now posting a status message every @StatusMessageInterval minutes
**						   - Added parameters @ForceResidueLevelComputation, @StatusMessageInterval, and @LastStatusUpdate
**			10/10/2006 mem - Optimized query for populating #TmpMassTagsConfirmed
**    
*****************************************************/
(
	@PMTQualityScoreMinimum real,
	@ComputeProteinResidueCoverage tinyint = 0,		-- When 1, then computes Protein coverage at the residue level; CPU intensive
	@ForceResidueLevelComputation tinyint = 0,		-- When 0, then if @ComputeProteinResidueCoverage = 1 then computes protein coverage at the residue level only for those proteins with changed values for Count_PMTs, Count_Confirmed, or Total_MSMS_Observation_Count; when 1, then sets @ComputeProteinResidueCoverage to 1 and recomputes residue level coverage for all proteins
	@numProteinsToProcess int = 0,					-- If greater than 0, then only processes this many proteins
	@StatusMessageInterval int = 5,					-- Number of minutes between status updates
	@LastStatusUpdate datetime output,
	@message varchar(255) = '' output
)
As

	Set nocount on
	
	Declare @myRowCount int	
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Declare	@Continue int,
			@RefID int,
			@ProteinSequenceLength int,
			@ProteinCoverageResidueCount int,
			@ProteinCoverageResidueCountConfirmed int,
			@ProcessCount int

	Set @ProcessCount = 0

	Declare @UpdateEnabled tinyint

	Declare @ProteinSequence varchar(8000),
			@ProteinSequenceConfirmed varchar(8000)

	Declare @LogMessage varchar(256)

	Declare @VerifyUpdateEnabledNow tinyint
	Set @VerifyUpdateEnabledNow = 0
	
	Declare @VerifyUpdateMessage varchar(255)
	Set @VerifyUpdateMessage = ''

	Declare @NumProteinsAvailable int
	Declare @NumProteinsSkipped int
	
	------------------------------------------
	-- Validate the inputs
	------------------------------------------
	--
	Set @message = ''

	Set @ForceResidueLevelComputation = IsNull(@ForceResidueLevelComputation, 0)
	If @ForceResidueLevelComputation <> 0
		Set @ComputeProteinResidueCoverage = 1
		
	Set @StatusMessageInterval = IsNull(@StatusMessageInterval, 5)
	If @StatusMessageInterval < 1
		Set @StatusMessageInterval = 1

	Set @LastStatusUpdate = IsNull(@LastStatusUpdate, GetDate())
	
	------------------------------------------
	-- Make sure all of the proteins in T_Proteins are present 
	-- in T_Protein_Coverage for the given @PMTQualityScoreMinimum value
	-- Do not include proteins that only contain entries in T_Mass_Tags
	-- with Internal_Standard_Only <> 0
	------------------------------------------

	INSERT INTO T_Protein_Coverage (
		Ref_ID, PMT_Quality_Score_Minimum,
		Count_PMTs, Count_PMTs_Full_Enzyme, Count_PMTs_Partial_Enzyme,
		Count_Confirmed, Total_MSMS_Observation_Count,
		High_Normalized_Score, High_Discriminant_Score 
		)
	SELECT T_Proteins.Ref_ID, @PMTQualityScoreMinimum,
		0 AS Count_PMTs, 0 AS Count_PMTs_Full_Enzyme, 0 AS Count_PMTs_Partial_Enzyme,
		0 AS Count_Confirmed, 0 AS Total_MSMS_Observation_Count,
		0 AS High_Normalized_Score, 0 AS High_Discriminant_Score 
	FROM T_Proteins LEFT OUTER JOIN T_Protein_Coverage
		ON T_Proteins.Ref_ID = T_Protein_Coverage.Ref_ID AND
		T_Protein_Coverage.PMT_Quality_Score_Minimum = @PMTQualityScoreMinimum
	WHERE T_Proteins.Ref_ID NOT IN (
			SELECT Ref_ID
			FROM (	SELECT T_Proteins.Ref_ID, 
					MIN(T_Mass_Tags.Internal_Standard_Only) AS IStdMin,
					MAX(T_Mass_Tags.Internal_Standard_Only) AS IStdMax 
					FROM T_Proteins INNER JOIN T_Mass_Tag_to_Protein_Map ON 
						 T_Proteins.Ref_ID = T_Mass_Tag_to_Protein_Map.Ref_ID
						 INNER JOIN T_Mass_Tags ON 
						 T_Mass_Tag_to_Protein_Map.Mass_Tag_ID = T_Mass_Tags.Mass_Tag_ID
					GROUP BY T_Proteins.Ref_ID
				) LookupQ
			WHERE IStdMin <> 0 AND IStdMax <> 0)
		 AND T_Protein_Coverage.Ref_ID Is Null
	--
	SELECT @myError = @@error, @myRowcount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Error adding missing proteins to T_Protein_Coverage'
		Set @myError = 53803
		Goto Done
	End

	------------------------------------------
	-- Update all the mass tag counts for the proteins in the coverage table 
	-- for the given @PMTQualityScoreMinimum value
	-- Using IsNull and Left Outer Join to assure that all proteins are updated
	------------------------------------------
	--
	-- Note: The following returns the message 'Warning: Null value is eliminated by an aggregate or other Set operation.'
	--       Not sure why, but the stats seem accurate
	--
	UPDATE T_Protein_Coverage
	Set Count_PMTs = Q.Count_PMTs,
		Count_PMTs_Full_Enzyme = Q.Count_PMTs_Full_Enzyme,
		Count_PMTs_Partial_Enzyme = Q.Count_PMTs_Partial_Enzyme,
		Count_Confirmed = Q.Count_Confirmed,
		Total_MSMS_Observation_Count = Q.Total_MSMS_Observation_Count,
		High_Normalized_Score = Q.High_Normalized_Score,
		High_Discriminant_Score = Q.High_Discriminant_Score
	FROM T_Protein_Coverage INNER JOIN 
		(
			SELECT T_Proteins.Ref_ID, 
				ISNULL(StatsQ.Count_PMTs, 0) AS Count_PMTs, 
				ISNULL(StatsQ.Count_PMTs_Full_Enzyme, 0) AS Count_PMTs_Full_Enzyme, 
				ISNULL(StatsQ.Count_PMTs_Partial_Enzyme, 0) AS Count_PMTs_Partial_Enzyme, 
				ISNULL(StatsQ.Count_Confirmed, 0) AS Count_Confirmed,
				ISNULL(StatsQ.Total_MSMS_Observation_Count, 0) AS Total_MSMS_Observation_Count,
				ISNULL(StatsQ.High_Normalized_Score, 0) AS High_Normalized_Score,
				ISNULL(StatsQ.High_Discriminant_Score, 0) AS High_Discriminant_Score
			FROM T_Proteins LEFT OUTER JOIN
					(	SELECT	P.Ref_ID, 
								COUNT(MT.Mass_Tag_ID) AS Count_PMTs,
								SUM (	CASE WHEN IsNull(MTPM.Cleavage_State, 0) = 2
										THEN 1
										ELSE 0
										End
									) AS Count_PMTs_Full_Enzyme,								
								SUM (	CASE WHEN IsNull(MTPM.Cleavage_State, 0) = 1
										THEN 1
										ELSE 0
										End
									) AS Count_PMTs_Partial_Enzyme,								
								ConfirmedQ.Count_Confirmed, 
								SUM(MT.Number_Of_Peptides) AS Total_MSMS_Observation_Count, 
								MAX(MT.High_Normalized_Score) AS High_Normalized_Score, 
								MAX(MT.High_Discriminant_Score) AS High_Discriminant_Score
						FROM T_Proteins AS P INNER JOIN T_Mass_Tag_to_Protein_Map AS MTPM ON P.Ref_ID = MTPM.Ref_ID 
							 INNER JOIN T_Mass_Tags AS MT ON MTPM.Mass_Tag_ID = MT.Mass_Tag_ID
							 LEFT OUTER JOIN (	SELECT Ref_ID, COUNT(Mass_Tag_ID) AS Count_Confirmed
												FROM (	SELECT PCP.Ref_ID, PCP.Mass_Tag_ID
														FROM V_Proteins_and_Confirmed_PMTs AS PCP INNER JOIN 
															 T_Mass_Tags AS MT ON PCP.Mass_Tag_ID = MT.Mass_Tag_ID
														WHERE MT.PMT_Quality_Score >= @PMTQualityScoreMinimum
													 ) As ConfirmedListQ
												GROUP BY Ref_ID
											 ) AS ConfirmedQ ON P.Ref_ID = ConfirmedQ.Ref_ID
						WHERE MT.PMT_Quality_Score >= @PMTQualityScoreMinimum
						GROUP BY P.Ref_ID, ConfirmedQ.Count_Confirmed
					) AS StatsQ ON T_Proteins.Ref_ID = StatsQ.Ref_ID
		  )	AS Q ON T_Protein_Coverage.Ref_ID = Q.Ref_ID AND 
			T_Protein_Coverage.PMT_Quality_Score_Minimum = @PMTQualityScoreMinimum
	--
	SELECT @myError = @@error, @myRowcount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Could not update entries in coverage table'
		Set @myError = 53804
		Goto Done
	End
	Else
	Begin
		-- Cannot use the @myRowCount value returned by the Update query above, since it will only
		-- indicate the number of Proteins with non-zero counts
		Set @myRowCount = 0
		SELECT @myRowCount = Count(Ref_ID)
		FROM T_Protein_Coverage
		WHERE PMT_Quality_Score_Minimum = @PMTQualityScoreMinimum
		--
		Set @message = 'Updated coverage counts for ' + convert(varchar(11), @myRowCount) + ' Proteins'
	End

	------------------------------------------
	-- If @ComputeProteinResidueCoverage = 1 then 
	-- compute Protein Coverage at the residue level
	------------------------------------------
	If @ComputeProteinResidueCoverage <> 0
	Begin -- <a>

		exec VerifyUpdateEnabled @CallingFunctionDescription = 'ComputeProteinCoverage', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @VerifyUpdateMessage output
		If @UpdateEnabled = 0
		Begin
			Set @message = @message + ' (aborted mid-processing since PMT_Tag_DB_Update is disabled in MT_Main)'
			Goto Done
		End	

		If DateDiff(second, @LastStatusUpdate, GetDate()) / 60.0 >= @StatusMessageInterval
		Begin
			Set @LogMessage = 'Starting residue level computation'
			execute PostLogEntry 'Progress', @LogMessage, 'ComputeProteinCoverageWork'
			Set @LastStatusUpdate = GetDate()
		End

		-- Step through each of the Proteins in T_Protein_Coverage for this 
		--  @ComputeProteinResidueCoverage level and compute the Protein coverage 
		-- at the residue level
		
		If @ForceResidueLevelComputation = 0
		Begin -- <b1>
			-- Reset the coverages for the Proteins as this @ComputeProteinResidueCoverage level
			-- Only reset those Proteins that are new or have different values than those in #ProteinCoverageSaved
			--
			-- First, reset the new Proteins (probably already have Null values for these columns)
			UPDATE T_Protein_Coverage
			Set Coverage_PMTs = Null, Coverage_Confirmed = Null
			FROM T_Protein_Coverage AS PC LEFT OUTER JOIN #ProteinCoverageSaved ON
				PC.Ref_ID = #ProteinCoverageSaved.Ref_ID AND 
				#ProteinCoverageSaved.PMT_Quality_Score_Minimum = PC.PMT_Quality_Score_Minimum
			WHERE PC.PMT_Quality_Score_Minimum = @PMTQualityScoreMinimum AND
				PC.Ref_ID Is Null
			--
			SELECT @myError = @@error, @myRowcount = @@rowcount
			--
			If @myError <> 0
			Begin
				Set @message = 'Error setting new Protein entries to Null'
				Set @myError = 53805
				Goto Done
			End
			
			-- Next, reset the changed Proteins
			UPDATE T_Protein_Coverage
			Set Coverage_PMTs = Null, Coverage_Confirmed = Null
			FROM T_Protein_Coverage AS PC INNER JOIN #ProteinCoverageSaved ON
				PC.Ref_ID = #ProteinCoverageSaved.Ref_ID AND 
				#ProteinCoverageSaved.PMT_Quality_Score_Minimum = PC.PMT_Quality_Score_Minimum
			WHERE PC.PMT_Quality_Score_Minimum = @PMTQualityScoreMinimum AND
				(
					PC.Count_PMTs <> #ProteinCoverageSaved.Count_PMTs OR
					PC.Count_Confirmed <> #ProteinCoverageSaved.Count_Confirmed OR
					PC.Total_MSMS_Observation_Count <> #ProteinCoverageSaved.Total_MSMS_Observation_Count
				)
			--
			SELECT @myError = @@error, @myRowcount = @@rowcount
			--
			If @myError <> 0
			Begin
				Set @message = 'Error setting coverages for changed Protein entries to Null'
				Set @myError = 53806
				Goto Done
			End
		End -- </b1>
		Else
		Begin -- <b2>
			UPDATE T_Protein_Coverage
			SET Coverage_PMTs = Null, Coverage_Confirmed = Null
			WHERE PMT_Quality_Score_Minimum = @PMTQualityScoreMinimum
			--
			SELECT @myError = @@error, @myRowcount = @@rowcount
		End -- </b2>

		-- Count the number of proteins in T_Protein_Coverage that need to have protein coverage calculated
		SELECT @NumProteinsAvailable = COUNT(*) 
		FROM T_Protein_Coverage
		WHERE Coverage_PMTs Is Null AND
			  T_Protein_Coverage.PMT_Quality_Score_Minimum = @PMTQualityScoreMinimum

		-- Count the number of proteins in T_Protein_Coverage that do not need to have protein coverage calculated
		SELECT @NumProteinsSkipped = COUNT(*) 
		FROM T_Protein_Coverage
		WHERE Not Coverage_PMTs Is Null AND
			  T_Protein_Coverage.PMT_Quality_Score_Minimum = @PMTQualityScoreMinimum

		Set @NumProteinsAvailable = IsNull(@NumProteinsAvailable, 0)
		Set @NumProteinsSkipped = IsNull(@NumProteinsSkipped, 0)
	
		If @NumProteinsAvailable > 0
		Begin -- <b3>
			If DateDiff(second, @LastStatusUpdate, GetDate()) / 60.0 >= @StatusMessageInterval
			Begin
				Set @LogMessage = 'Populating temporary tables for residue level computation'
				execute PostLogEntry 'Progress', @LogMessage, 'ComputeProteinCoverageWork'
				Set @LastStatusUpdate = GetDate()
			End

			-- Populate temporary tables with the sequences associated with each Protein
			-- Useful to speed up the computations below
				
			CREATE TABLE #TmpMassTagsAll ([Ref_ID] int NOT NULL, [Peptide] varchar(750) NOT NULL) ON [PRIMARY]
			CREATE CLUSTERED INDEX #IX__TempTable__TmpMassTagsAll ON #TmpMassTagsAll([Ref_ID]) ON [PRIMARY]

			CREATE TABLE #TmpMassTagsConfirmed ([Ref_ID] int NOT NULL, [Peptide] varchar(750) NOT NULL) ON [PRIMARY]
			CREATE CLUSTERED INDEX #IX__TempTable__TmpMassTagsConfirmed ON #TmpMassTagsConfirmed([Ref_ID]) ON [PRIMARY]

			
			INSERT INTO #TmpMassTagsAll (Ref_ID, Peptide)
			SELECT	MTPM.Ref_ID, Upper(MT.Peptide)
			FROM	T_Mass_Tags AS MT INNER JOIN 
					T_Mass_Tag_to_Protein_Map AS MTPM ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID 
			WHERE	MT.Internal_Standard_Only = 0 AND 
					MT.PMT_Quality_Score >= @PMTQualityScoreMinimum
			--
			SELECT @myError = @@error, @myRowcount = @@rowcount
			--
			If @myError <> 0
			Begin
				Set @message = 'Error populating #TmpMassTagsAll'
				Set @myError = 53807
				Goto Done
			End

			If DateDiff(second, @LastStatusUpdate, GetDate()) / 60.0 >= @StatusMessageInterval
			Begin
				Set @LogMessage = 'Populated #TmpMassTagsAll for residue level computation'
				execute PostLogEntry 'Progress', @LogMessage, 'ComputeProteinCoverageWork'
				Set @LastStatusUpdate = GetDate()
			End

			INSERT INTO #TmpMassTagsConfirmed (Ref_ID, Peptide)
			SELECT	MTPM.Ref_ID, Upper(MT.Peptide)
			FROM	T_Mass_Tags AS MT INNER JOIN 
					T_Mass_Tag_to_Protein_Map AS MTPM ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID INNER JOIN	
						(	SELECT MT.Mass_Tag_ID
							FROM T_FTICR_UMC_Results UR INNER JOIN
								 T_FTICR_UMC_ResultDetails URD ON UR.UMC_Results_ID = URD.UMC_Results_ID INNER JOIN
								 T_Mass_Tags MT ON URD.Mass_Tag_ID = MT.Mass_Tag_ID INNER JOIN
								 T_Match_Making_Description MMD ON UR.MD_ID = MMD.MD_ID
							WHERE URD.Match_State = 6 AND MMD.MD_State <> 6 AND 
								  MT.PMT_Quality_Score >= @PMTQualityScoreMinimum
							GROUP BY MT.Mass_Tag_ID
						) AS ConfirmedListQ ON MT.Mass_Tag_ID = ConfirmedListQ.Mass_Tag_ID
			--
			SELECT @myError = @@error, @myRowcount = @@rowcount

			If DateDiff(second, @LastStatusUpdate, GetDate()) / 60.0 >= @StatusMessageInterval
			Begin
				Set @LogMessage = 'Populated #TmpMassTagsConfirmed for residue level computation'
				execute PostLogEntry 'Progress', @LogMessage, 'ComputeProteinCoverageWork'
				Set @LastStatusUpdate = GetDate()
			End

			-- Initialize variables required for Looping
			Set @Continue = 1
			Set @RefID = -1000000000
			Set @VerifyUpdateEnabledNow = 1
			
			If @numProteinsToProcess = 0
				Set @numProteinsToProcess = 1E8
			
			While @Continue = 1 AND @ProcessCount < @numProteinsToProcess
			Begin -- <c>
				-- Get next protein
				SELECT TOP 1 @RefID = Ref_ID
				FROM T_Protein_Coverage
				WHERE Ref_ID > @RefID AND Coverage_PMTs Is Null AND
					T_Protein_Coverage.PMT_Quality_Score_Minimum = @PMTQualityScoreMinimum
				ORDER By Ref_ID
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				If @myRowCount < 1
					Set @Continue = 0
				Else
				Begin -- <d>
					-- Get protein sequence for given Protein
					--
					SELECT	@ProteinSequence = IsNull(Protein_Sequence, '')
					FROM	T_Proteins
					WHERE	Ref_ID = @RefID
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					
					Set @ProteinSequenceLength = Len(@ProteinSequence)
					
					If @myRowCount = 1 And @ProteinSequenceLength > 0
					Begin -- <e>
						Set @ProteinSequence = Lower(@ProteinSequence)
						Set @ProteinSequenceConfirmed = @ProteinSequence
						
						-- Work through list of peptides for given Protein
						--   substituting upper case version of each peptide into the protein string
						--
						SELECT	@ProteinSequence = REPLACE (@ProteinSequence, #TmpMassTagsAll.Peptide, #TmpMassTagsAll.Peptide)
						FROM	#TmpMassTagsAll
						WHERE   #TmpMassTagsAll.Ref_ID = @RefID
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount
						
						-- Count the number of uppercase letters in @ProteinSequence
						If @myRowCount > 0
							exec CountCapitalLetters @ProteinSequence, @CapitalLetterCount = @ProteinCoverageResidueCount OUTPUT
						else
							Set @ProteinCoverageResidueCount = 0

						-- Do the same for @ProteinSequenceConfirmed
						SELECT	@ProteinSequenceConfirmed = REPLACE (@ProteinSequenceConfirmed, #TmpMassTagsConfirmed.Peptide, #TmpMassTagsConfirmed.Peptide)
						FROM	#TmpMassTagsConfirmed
						WHERE   #TmpMassTagsConfirmed.Ref_ID = @RefID
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount

						-- Count the number of uppercase letters in @ProteinSequenceConfirmed
						If @myRowCount > 0
							exec CountCapitalLetters @ProteinSequenceConfirmed, @CapitalLetterCount = @ProteinCoverageResidueCountConfirmed OUTPUT
						else
							Set @ProteinCoverageResidueCountConfirmed = 0
							
						-- Compute the coverages and save to T_Protein_Coverage
						UPDATE T_Protein_Coverage
						Set Coverage_PMTs = @ProteinCoverageResidueCount / Convert(float, @ProteinSequenceLength),
							Coverage_Confirmed = @ProteinCoverageResidueCountConfirmed / Convert(float, @ProteinSequenceLength)
						WHERE Ref_ID = @RefID AND
							T_Protein_Coverage.PMT_Quality_Score_Minimum = @PMTQualityScoreMinimum
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount
						--
						Set @ProcessCount = @ProcessCount + 1			
					End -- </e>
				End -- </d>

				If DateDiff(second, @LastStatusUpdate, GetDate()) / 60.0 >= @StatusMessageInterval
				Begin
					Set @LogMessage = 'Residue level computation for PMTQualityScoreMinimum = ' + Convert(varchar(12), @PMTQualityScoreMinimum) + '; Completed ' + Convert(varchar(12), @ProcessCount) + '/' + Convert(varchar(12), @NumProteinsAvailable)
					execute PostLogEntry 'Progress', @LogMessage, 'ComputeProteinCoverageWork'
					Set @LastStatusUpdate = GetDate()
					Set @VerifyUpdateEnabledNow = 1
				End
				
				If @ProcessCount % 100 = 0 Or @VerifyUpdateEnabledNow <> 0
				Begin
					-- Validate that updating is enabled, abort if not enabled
					exec VerifyUpdateEnabled @CallingFunctionDescription = 'ComputeProteinCoverageWork', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @VerifyUpdateMessage output
					If @UpdateEnabled = 0
					Begin
						Set @message = @message + '; updated coverage fractions for ' + convert(varchar(11), @ProcessCount) + ' Proteins (aborted mid-processing since PMT_Tag_DB_Update is disabled in MT_Main)'
						Goto Done
					End
					Set @VerifyUpdateEnabledNow = 0
				End
			End -- </c>
		End -- </b>

		Set @message = @message + '; updated coverage fractions for ' + convert(varchar(11), @ProcessCount) + ' Proteins'
		If @NumProteinsSkipped > 0
			Set @message = @message + ' (skipped ' + Convert(varchar(9), @NumProteinsSkipped) + ' proteins since PMT and Observation counts are unchanged)'

	End -- </a>
	Else
		Set @message = @message + ' (skipped coverage fraction computation)'

Done:	
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[ComputeProteinCoverageWork] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[ComputeProteinCoverageWork] TO [MTS_DB_Lite]
GO
