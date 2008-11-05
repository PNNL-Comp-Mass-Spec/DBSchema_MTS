/****** Object:  StoredProcedure [dbo].[QuantitationProcessWorkStepB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.QuantitationProcessWorkStepB
/****************************************************	
**  Desc: 
**
**  Return values: 0 if success, otherwise, error code
**
**  Auth:	mem
**	Date:	09/07/2006
**			05/28/2007 mem - Now calling QuantitationProcessCheckForMSMSPeptideIDs to populate 
**							 column Observed_By_MSMS_in_This_Dataset by looking for Sequest or
**							 XTandem results from the datasets corresponding to the jobs in #UMCMatchResultsByJob
**			06/04/2007 mem - Now filtering on match score if either @MinimumMatchScore or @MinimumDelMatchScore is non-zero
**			06/06/2007 mem - Now populating Rank_Match_Score_Avg, then filtering based on parameter @MaximumMatchesPerUMCToKeep
**			06/08/2007 mem - Updated call to QuantitationProcessCheckForMSMSPeptideIDs to include score filters
**			10/20/2008 mem - Added Try/Catch error handling
**
****************************************************/
(
	@QuantitationID int,
	@InternalStdInclusionMode tinyint,			-- 0 for no NET lockers, 1 for PMT tags and NET Lockers, 2 for NET lockers only
	@UMCAbundanceMode tinyint,					-- 0 to use the value in T_FTICR_UMC_Results (typically peak area); 1 to use the peak maximum
	@ERMode tinyint,							-- 0 to use Expression_Ratio_Recomputed (treat multiple UMCs matching same same mass tag in same job as essentially one large UMC), 1 to use Expression_Ratio_WeightedAvg (weight multiple ER values for same mass tag by UMC member counts)

	@MinimumMTHighNormalizedScore real,			-- 0 to use all mass tags, > 0 to filter by XCorr
	@MinimumMTHighDiscriminantScore real,		-- 0 to use all mass tags, > 0 to filter by Discriminant Score
	@MinimumMTPeptideProphetProbability real,	-- 0 to use all mass tags, > 0 to filter by Peptide_Prophet_Probability
	@MinimumPMTQualityScore real,				-- 0 to use all mass tags, > 0 to filter by PMT Quality Score (as currently set in T_Mass_Tags)

	@MinimumPeptideLength tinyint,				-- 0 to use all mass tags, > 0 to filter by peptide length
	@MaximumMatchesPerUMCToKeep smallint,		-- 0 to use all matches for each UMC, > 0 to only use the top @MaximumMatchesPerUMCToKeep matches to each UMC (favoring the ones with the closest SLiC score first); matches with identical SLiC scores will all be used
	@MinimumMatchScore real,					-- 0 to use all mass tag matches, > 0 to filter by Match Score (aka SLiC Score, which indicates the uniqueness of a given mass tag matching a given UMC)
	@MinimumDelMatchScore real,					-- 0 to use all mass tag matches, > 0 to filter by Del Match Score (aka Del SLiC Score); only used if @MinimumMatchScore is > 0

	@message varchar(512)='' output
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @ResultsCount int
	set @ResultsCount = 0
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try

		-----------------------------------------------------------
		-- Step 5
		--
		-- In order to speed up the following queries, it is advantageous to copy the 
		-- UMC match results for the corresponding MD_ID's to a temporary table
		--
		-- When creating the table, we combine the data from T_FTICR_UMC_Results
		--  and T_FTICR_UMC_ResultDetails
		--
		-- When populating this table, we sum the abundances for multiple UMC's in the
		--  same job that matched the same peptide; first, though, we'll copy the
		-- raw data into #UMCMatchResultsSoure.  We need to this first because the 
		-- MTAbundance column can contain data from either Class_Abundance or Abundance_Max
		-- and we also want to compute MTAbundanceLightPlusHeavy
		--
		-----------------------------------------------------------
		--
		-- Step 5a
		--
		-- Define the fields for the temporary table that will hold the source data for the #UMCMatchResultsByJob table

		if exists (select * from dbo.sysobjects where id = object_id(N'[#UMCMatchResultsSource]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [#UMCMatchResultsSource]

		CREATE TABLE #UMCMatchResultsSource (
			[UniqueID] int identity(1,1) NOT NULL ,
			[MD_ID] int NOT NULL ,
			[Job] int NOT NULL ,
			[TopLevelFraction] smallint NOT NULL ,
			[Fraction] smallint NOT NULL ,
			[Replicate] smallint NOT NULL ,
			[InternalStdMatch] tinyint NOT NULL ,
			[Mass_Tag_ID] int NOT NULL ,
			[High_Normalized_Score] real NOT NULL ,
			[High_Discriminant_Score] real NOT NULL ,
			[High_Peptide_Prophet_Probability] real NOT NULL ,
			[PMT_Quality_Score] real NOT NULL ,
			[Mass_Tag_Mods] [varchar](50) NOT NULL ,
			[MTAbundance] float NOT NULL ,
			[MTAbundanceLightPlusHeavy] float NOT NULL ,
			[Member_Count_Used_For_Abu] int NOT NULL ,
			[UMC_Ind] int NOT NULL ,
			[Member_Count] int NOT NULL ,
			[Matching_Member_Count] int NOT NULL ,
			[Match_Score] float NOT NULL ,
			[Del_Match_Score] real NOT NULL ,
			[MassTag_Hit_Count] int NOT NULL ,
			[Scan_First] int NOT NULL ,
			[Scan_Last] int NOT NULL ,
			[ElutionTime] real NOT NULL ,
			[MT_Avg_GANET] float NULL ,
			[MT_PNET] float NULL ,
			[Expression_Ratio] float NOT NULL ,
			[Expression_Ratio_StDev] float NULL ,
			[Expression_Ratio_Charge_State_Basis_Count] smallint NULL ,
			[Class_Stats_Charge_Basis] smallint NOT NULL ,
			[Charge_State_Min] smallint NOT NULL ,
			[Charge_State_Max] smallint NOT NULL ,
			[MassErrorPPM] float NOT NULL ,
			[Rank_Match_Score] smallint NULL
		) ON [PRIMARY]

		If @InternalStdInclusionMode = 0 OR @InternalStdInclusionMode = 1
		Begin
			--
			-- Step 5b - Populate the temporary table with PMT tag matches
			--
			INSERT INTO #UMCMatchResultsSource
			   (MD_ID,
				Job,
				TopLevelFraction, 
				Fraction, 
				[Replicate], 
				InternalStdMatch,
				Mass_Tag_ID, 
				High_Normalized_Score,
				High_Discriminant_Score,
				High_Peptide_Prophet_Probability,
				PMT_Quality_Score,
				Mass_Tag_Mods,
				MTAbundance, 
				MTAbundanceLightPlusHeavy,
				Member_Count_Used_For_Abu,
				UMC_Ind,
				Member_Count, 
				Matching_Member_Count,
				Match_Score,
				Del_Match_Score,
				MassTag_Hit_Count,
				Scan_First,
				Scan_Last,
				ElutionTime,
				MT_Avg_GANET,
				MT_PNET,
				Expression_Ratio,
				Expression_Ratio_StDev,
				Expression_Ratio_Charge_State_Basis_Count,
				Class_Stats_Charge_Basis,
				Charge_State_Min,
				Charge_State_Max,
				MassErrorPPM)
			SELECT	MMD.MD_ID,
					MMD.MD_Reference_Job,
					TMDID.TopLevelFraction, 
					TMDID.Fraction, 
					TMDID.[Replicate], 
					0 AS InternalStdMatch,
					RD.Mass_Tag_ID,
					IsNull(MT.High_Normalized_Score,0),
					IsNull(MT.High_Discriminant_Score,0),
					IsNull(MT.High_Peptide_Prophet_Probability,0),
					IsNull(MT.PMT_Quality_Score,0),
					RD.Mass_Tag_Mods,
								
					CASE WHEN @UMCAbundanceMode = 0 
					THEN IsNull(R.Class_Abundance,0)			-- Use the defined abundance value
					ELSE IsNull(R.Abundance_Max,0)				-- Use maximum abundance for peak
					END,		-- MTAbundance 

					CASE WHEN ABS(IsNull(R.Expression_Ratio,0)) < 1E100 AND ABS(IsNull(R.Expression_Ratio,0)) > 1E-10
					THEN
						CASE WHEN @UMCAbundanceMode = 0 
						THEN IsNull(R.Class_Abundance,0) + IsNull(R.Class_Abundance,0) / R.Expression_Ratio
						ELSE IsNull(R.Abundance_Max,0) + IsNull(R.Abundance_Max,0) / R.Expression_Ratio
						END				
					ELSE 0
					END,		-- MTAbundanceLightPlusHeavy; Light Abu + Heavy Abu; Compute Heavy Abu using Light / ER; substitute, find Sum = Light + Light / ER
					
					IsNull(R.Member_Count_Used_For_Abu, 0),

					R.UMC_Ind,
					R.Member_Count,
					IsNull(RD.Matching_Member_Count, 0),
					IsNull(RD.Match_Score, -1),
					IsNull(RD.Del_Match_Score, 0),
					
					R.MassTag_Hit_Count,
					R.Scan_First,
					R.Scan_Last,
					IsNull(R.ElutionTime, 0),										-- ElutionTime
					
					MTN.AVG_GANET,		-- MT_Avg_GANET: Average observed GANET for mass_tag_ID
					MTN.PNET,			-- MT_PNET: Predicted NET for mass_tag_ID

					CASE WHEN ABS(IsNull(R.Expression_Ratio,0)) < 1E+100 AND ABS(IsNull(R.Expression_Ratio,0)) > 1E-10
					THEN R.Expression_Ratio
					ELSE 0
					END,									-- Expression_Ratio; note: guaranteed after this point to be between 1E-10 and 1E+100, or 0

					CASE WHEN ABS(IsNull(R.Expression_Ratio,0)) < 1E+100 AND ABS(IsNull(R.Expression_Ratio,0)) > 1E-10
					THEN IsNull(R.Expression_Ratio_StDev, 0)
					ELSE 0
					END,									-- Expression_Ratio_StDev

					CASE WHEN ABS(IsNull(R.Expression_Ratio,0)) < 1E+100 AND ABS(IsNull(R.Expression_Ratio,0)) > 1E-10
					THEN IsNull(R.Expression_Ratio_Charge_State_Basis_Count, 0)
					ELSE 0
					END,									-- Expression_Ratio_Charge_State_Basis_Count
					
					IsNull(R.Class_Stats_Charge_Basis, 0),
					IsNull(R.Charge_State_Min, 0),
					IsNull(R.Charge_State_Max, 0),
					
					CASE WHEN IsNull(MT.Monoisotopic_Mass,0) > 0 
					THEN 1E6 * ((R.Class_Mass - RD.Mass_Tag_Mod_Mass) - MT.Monoisotopic_Mass) / MT.Monoisotopic_Mass		-- Mass Error PPM; correcting for mass mods by subtracting Mass_Tag_Mod_Mass
					ELSE 0 
					END
			FROM T_Quantitation_MDIDs TMDID
				INNER JOIN T_Match_Making_Description MMD ON 
					TMDID.MD_ID = MMD.MD_ID
	   			INNER JOIN T_FTICR_UMC_Results AS R
					ON MMD.MD_ID = R.MD_ID
				INNER JOIN T_FTICR_UMC_ResultDetails AS RD
					ON R.UMC_Results_ID = RD.UMC_Results_ID
				INNER JOIN T_Mass_Tags AS MT
					ON RD.Mass_Tag_ID = MT.Mass_Tag_ID
				LEFT OUTER JOIN T_Mass_Tags_NET AS MTN
					ON RD.Mass_Tag_ID = MTN.Mass_Tag_ID
			WHERE TMDID.Quantitation_ID = @QuantitationID AND RD.Match_State = 6			-- Only include matches with a state of 6 = Hit
			ORDER BY TMDID.TopLevelFraction, TMDID.Fraction, RD.Mass_Tag_ID, RD.Mass_Tag_Mods, RD.Mass_Tag_Mod_Mass, TMDID.[Replicate]
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount
			--
			If @myError <> 0 
			Begin
				Set @message = 'Error while populating the #UMCMatchResultsSource temporary table from T_FTICR_UMC_ResultDetails'
				Set @myError = 118
				Goto Done
			End
			
			Set @ResultsCount = @ResultsCount + @myRowCount
		End

		If @InternalStdInclusionMode = 1 OR @InternalStdInclusionMode = 2
		Begin	
			--
			-- Step 5c - Populate the temporary table with the Internal Standard Matches
			--			 Do not add new matches for PMTs that are already present
			--
			INSERT INTO #UMCMatchResultsSource
			   (MD_ID,
				Job,
				TopLevelFraction, 
				Fraction, 
				[Replicate], 
				InternalStdMatch,
				Mass_Tag_ID, 
				High_Normalized_Score,
				High_Discriminant_Score,
				High_Peptide_Prophet_Probability,
				PMT_Quality_Score,
				Mass_Tag_Mods,
				MTAbundance, 
				MTAbundanceLightPlusHeavy,
				Member_Count_Used_For_Abu,
				UMC_Ind,
				Member_Count, 
				Matching_Member_Count,
				Match_Score,
				Del_Match_Score,
				MassTag_Hit_Count,
				Scan_First,
				Scan_Last,
				ElutionTime,
				MT_Avg_GANET,
				MT_PNET,
				Expression_Ratio,
				Expression_Ratio_StDev,
				Expression_Ratio_Charge_State_Basis_Count,
				Class_Stats_Charge_Basis,
				Charge_State_Min,
				Charge_State_Max,
				MassErrorPPM)
			SELECT	MMD.MD_ID,
					MMD.MD_Reference_Job,
					TMDID.TopLevelFraction, 
					TMDID.Fraction, 
					TMDID.[Replicate], 
					1 AS InternalStdMatch,
					ISD.Seq_ID,					-- Mass_Tag_ID
					IsNull(MT.High_Normalized_Score,0),
					IsNull(MT.High_Discriminant_Score,0),
					IsNull(MT.High_Peptide_Prophet_Probability,0),
					IsNull(MT.PMT_Quality_Score,0),
					'',							-- Mass_Tag_Mods
								
					CASE WHEN @UMCAbundanceMode = 0 
					THEN IsNull(R.Class_Abundance,0)			-- Use the defined abundance value
					ELSE IsNull(R.Abundance_Max,0)				-- Use maximum abundance for peak
					END,		-- MTAbundance 

					CASE WHEN ABS(IsNull(R.Expression_Ratio,0)) < 1E100 AND ABS(IsNull(R.Expression_Ratio,0)) > 1E-10
					THEN
						CASE WHEN @UMCAbundanceMode = 0 
						THEN IsNull(R.Class_Abundance,0) + IsNull(R.Class_Abundance,0) / R.Expression_Ratio
						ELSE IsNull(R.Abundance_Max,0) + IsNull(R.Abundance_Max,0) / R.Expression_Ratio
						END				
					ELSE 0
					END,		-- MTAbundanceLightPlusHeavy; Light Abu + Heavy Abu; Compute Heavy Abu using Light / ER; substitute, find Sum = Light + Light / ER
					
					IsNull(R.Member_Count_Used_For_Abu, 0),

					R.UMC_Ind,
					R.Member_Count,
					IsNull(ISD.Matching_Member_Count, 0),
					IsNull(ISD.Match_Score, -1),
					IsNull(ISD.Del_Match_Score, 0),
					
					R.MassTag_Hit_Count,
					R.Scan_First,
					R.Scan_Last,
					IsNull(R.ElutionTime, 0),										-- ElutionTime
					
					ISC.AVG_NET,		-- Average observed NET for the Internal Standard
					ISC.PNET,			-- Predicted NET for the Internal Standard

					CASE WHEN ABS(IsNull(R.Expression_Ratio,0)) < 1E+100 AND ABS(IsNull(R.Expression_Ratio,0)) > 1E-10
					THEN R.Expression_Ratio
					ELSE 0
					END,									-- Expression_Ratio; note: guaranteed after this point to be between 1E-10 and 1E+100, or 0

					CASE WHEN ABS(IsNull(R.Expression_Ratio,0)) < 1E+100 AND ABS(IsNull(R.Expression_Ratio,0)) > 1E-10
					THEN IsNull(R.Expression_Ratio_StDev, 0)
					ELSE 0
					END,									-- Expression_Ratio_StDev

					CASE WHEN ABS(IsNull(R.Expression_Ratio,0)) < 1E+100 AND ABS(IsNull(R.Expression_Ratio,0)) > 1E-10
					THEN IsNull(R.Expression_Ratio_Charge_State_Basis_Count, 0)
					ELSE 0
					END,									-- Expression_Ratio_Charge_State_Basis_Count
					
					IsNull(R.Class_Stats_Charge_Basis, 0),
					IsNull(R.Charge_State_Min, 0),
					IsNull(R.Charge_State_Max, 0),
					
					CASE WHEN IsNull(MT.Monoisotopic_Mass,0) > 0 
					THEN 1E6 * ((R.Class_Mass -        0            ) - MT.Monoisotopic_Mass) / MT.Monoisotopic_Mass		-- Mass Error PPM
					ELSE 0 
					END
			FROM T_Quantitation_MDIDs TMDID
				INNER JOIN T_Match_Making_Description MMD ON 
					TMDID.MD_ID = MMD.MD_ID
	   			INNER JOIN T_FTICR_UMC_Results AS R
					ON MMD.MD_ID = R.MD_ID
				INNER JOIN T_FTICR_UMC_InternalStdDetails AS ISD
					ON R.UMC_Results_ID = ISD.UMC_Results_ID
				INNER JOIN MT_Main.dbo.T_Internal_Std_Components AS ISC 
					ON ISD.Seq_ID = ISC.Seq_ID
				INNER JOIN T_Mass_Tags AS MT
					ON ISC.Seq_ID = MT.Mass_Tag_ID
				LEFT OUTER JOIN #UMCMatchResultsSource AS UMRS ON
					UMRS.TopLevelFraction = TMDID.TopLevelFraction AND
					UMRS.Fraction = TMDID.Fraction AND
					UMRS.[Replicate] = TMDID.[Replicate] AND
					UMRS.Mass_Tag_ID = ISD.Seq_ID
			WHERE TMDID.Quantitation_ID = @QuantitationID AND ISD.Match_State = 6			-- Only include matches with a state of 6 = Hit
				  AND UMRS.Mass_Tag_ID IS NULL
			ORDER BY TMDID.TopLevelFraction, TMDID.Fraction, ISD.Seq_ID, TMDID.[Replicate]
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount
			--
			If @myError <> 0 
			Begin
				Set @message = 'Error while populating the #UMCMatchResultsSource temporary table from T_FTICR_UMC_InternalStdDetails'
				Set @myError = 119
				Goto Done
			End
			
			Set @ResultsCount = @ResultsCount + @myRowCount
		End

		--
		-- Step 5d - Possibly delete low scoring matches
		--
		If (@MinimumMatchScore > 0 OR @MinimumDelMatchScore > 0) AND @ResultsCount > 0
		Begin
			-- Transact-SQL delete notation
			DELETE FROM #UMCMatchResultsSource
			WHERE NOT (Match_Score >= @MinimumMatchScore AND Del_Match_Score >= @MinimumDelMatchScore)
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount
			--
			If @myError <> 0 
			Begin
				Set @message = 'Error removing the low scoring matches from the #UMCMatchResultsSource temporary table'
				Set @myError = 120
				Goto Done
			End
			--
			If @myRowCount > 0
			Begin
				SELECT @myRowCount = Count(Mass_Tag_ID)
				FROM #UMCMatchResultsSource
				--
				If @myRowCount = 0
				Begin
					-- Post an error message to T_Log_Entries
					set @message = 'All matching mass tags were filtered out by the Minimum_Match_Score (SLiC Score) value of ' + Convert(varchar(12), Round(@MinimumMatchScore, 3)) + ' and Minimum_Del_Match_Score of ' +  Convert(varchar(12), Round(@MinimumDelMatchScore, 3)) + ' for Quantitation_ID = ' + convert(varchar(19), @QuantitationID) + ' listed in T_Quantitation_MDIDs'
					set @myError = 121
					goto Done
				End
			End
		End
		

		--
		-- Step 5e - Populate Rank_Match_Score in #UMCMatchResultsSource
		--
		If @ResultsCount > 0
		Begin
		
			UPDATE #UMCMatchResultsSource
			SET Rank_Match_Score = RankQ.DenseRank
			FROM #UMCMatchResultsSource Src
				INNER JOIN ( SELECT UniqueID, 
									Dense_Rank() OVER ( PARTITION BY MD_ID, UMC_Ind ORDER BY Match_Score DESC ) AS DenseRank
							FROM #UMCMatchResultsSource
						   ) RankQ ON Src.UniqueID = RankQ.UniqueID
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount

			If IsNull(@MaximumMatchesPerUMCToKeep, 0) > 0
			Begin
				-- Only keep the top @MaximumMatchesPerUMCToKeep score values for each UMC
				-- Since we used Dense_Rank() above, if multiple Mass Taqs have the same Match_Score values, then
				--  they're given the same Rank value
				DELETE #UMCMatchResultsSource
				WHERE Rank_Match_Score > @MaximumMatchesPerUMCToKeep
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount
			End
		End
		
		--
		-- Step 5f - Populate the temporary table
		-- For now, we only rollup by UMC; we'll roll up by replicate, fraction,
		--  and top level fraction later
		--
		--
		INSERT INTO #UMCMatchResultsByJob
			(Job,
			 TopLevelFraction, 
			 Fraction, 
			 [Replicate], 
			 InternalStdMatch,
			 Mass_Tag_ID, 
			 Observed_By_MSMS_in_This_Dataset,
			 High_Normalized_Score,
			 High_Discriminant_Score,
			 High_Peptide_Prophet_Probability,
			 PMT_Quality_Score,
			 Mass_Tag_Mods,
			 MTAbundance, 
			 MTAbundanceLightPlusHeavy,
			 Member_Count_Used_For_Abu,
			 UMCMatchCount, 
			 UMCIonCountTotal, UMCIonCountMatch,

			 UMCIonCountMatchInUMCsWithSingleHit, FractionScansMatchingSingleMT,
			 UMCMultipleMTHitCountAvg, UMCMultipleMTHitCountStDev,
			 UMCMultipleMTHitCountMin, UMCMultipleMTHitCountMax,
			 Rank_Match_Score_Avg,
			 Match_Score_Avg,
			 Del_Match_Score_Avg,
			 NET_Error_Obs_Avg,
			 NET_Error_Pred_Avg,
			 ER_WeightedAvg,					-- Weighted average expression ratio for given mass tag with several matching UMCs
			 ER_StDev,							-- Weighted average ER standard deviation
			 ER_Charge_State_Basis_Count_Avg,
			 MTAbundanceLight,
			 MTAbundanceHeavy,
			 ER_Recomputed,						-- Average ER for given mass tag with several matching UMCs; sum light UMC abundances and heavy UMC abundances, and re-compute average; compute below
			 ER_ToUse,
			 ScanMinimum,
			 ScanMaximum,
			 NET_Minimum,
			 NET_Maximum,
			 Class_Stats_Charge_Basis_Avg,
			 Charge_State_Min,
			 Charge_State_Max,
			 MassErrorPPMAvg,
			 UseValue)
		SELECT	Job,
				TopLevelFraction, 
				Fraction, 
				[Replicate], 
				InternalStdMatch,
				Mass_Tag_ID,
				0 AS Observed_By_MSMS_in_This_Dataset,
				Max(High_Normalized_Score),
				Max(High_Discriminant_Score),
				Max(High_Peptide_Prophet_Probability),
				Max(PMT_Quality_Score),
				Mass_Tag_Mods,
				Sum(MTAbundance),
				Sum(MTAbundanceLightPlusHeavy),
				SUM(Member_Count_Used_For_Abu),				-- Member_Count_Used_For_Abu; Sum, since we're summing MTAbundance
				COUNT(UMC_Ind),			-- UMCMatchCount
				SUM(Member_Count),		-- UMCIonCountTotal
				SUM(Matching_Member_Count),		-- UMCIonCountMatch
				-- The following is a conditional sum: we only sum Matching_Member_Count if
				--  MassTag_Hit_Count = 1
				SUM(	CASE WHEN MassTag_Hit_Count = 1
						THEN Matching_Member_Count
						ELSE 0
						END),									-- UMCIonCountMatchInUMCsWithSingleHit
				CONVERT(real, 0),						-- FractionScansMatchingSingleMT
				AVG(CONVERT(real, MassTag_Hit_Count)),
				STDEV(CONVERT(real, MassTag_Hit_Count)),	-- UMCMultipleMTHitCountStDev; this will be Null if only one UMC matched this mass tag
				MIN(MassTag_Hit_Count), 
				MAX(MassTag_Hit_Count),		-- UMCMultipleMTHitCountMax
				AVG(Rank_Match_Score),		-- Rank_Match_Score_Avg: Rank 1 is top hit, rank 2 is 2nd, etc.
				AVG(Match_Score),			-- Match_Score_Avg: Match_Score holds the likelihood of the match, a value between 0 and 1, or -1 if undefined
				AVG(Del_Match_Score),		-- Del_Match_Score_Avg: Del_Match_Score holds the distance of the given match to highest scoring match
				AVG(ElutionTime - IsNull(MT_Avg_GANET, ElutionTime)),		-- NET_Error_Obs_Avg
				AVG(ElutionTime - IsNull(MT_PNET, ElutionTime)),			-- NET_Error_Pred_Avg
				CASE WHEN SUM(MTAbundanceLightPlusHeavy) > 0
				THEN SUM(Expression_Ratio * MTAbundanceLightPlusHeavy) / SUM(MTAbundanceLightPlusHeavy)
				ELSE 0
				END,				-- ER_WeightedAvg; weighted average

				CASE WHEN SUM(MTAbundanceLightPlusHeavy) > 0
				THEN SQRT(SUM(SQUARE(Expression_Ratio_StDev) * MTAbundanceLightPlusHeavy) / SUM(MTAbundanceLightPlusHeavy))
				ELSE 0
				END,				-- ER_StDev; weighted average

				Avg(Convert(real, Expression_Ratio_Charge_State_Basis_Count)),		-- ER_Charge_State_Basis_Count_Avg

				SUM(CASE WHEN ABS(Expression_Ratio) > 0
					THEN MTAbundance						-- MTAbundanceLight: Sum of Light Abundance, but only if Expression_Ratio > 0
					ELSE 0
					END),
					
				SUM(CASE WHEN ABS(Expression_Ratio) > 0
					THEN MTAbundance / Expression_Ratio
					ELSE 0
					END),
				0,					-- ER_Recomputed; populated below
				0,					-- ER_ToUse; populated below
				Min(Scan_First),
				Max(Scan_Last),
				Min(ElutionTime),												-- NET_Minimum
				Max(ElutionTime),												-- NET_Maximum
				Avg(Convert(real, Class_Stats_Charge_Basis)),					-- Class_Stats_Charge_Basis_Avg
				Min(Charge_State_Min),
				Max(Charge_State_Max),
				AVG(MassErrorPPM),
				1					-- UseValue is initially set to 1; it will be changed to 0 below as needed if filtering out outliers
		FROM #UMCMatchResultsSource
		GROUP BY Job, TopLevelFraction, Fraction, InternalStdMatch, Mass_Tag_ID, Mass_Tag_Mods, [Replicate]
		ORDER BY TopLevelFraction, Fraction, InternalStdMatch, Mass_Tag_ID, Mass_Tag_Mods, [Replicate]
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error while populating the #UMCMatchResultsByJob temporary table'
			Set @myError = 122
			Goto Done
		End
		--
		If @myRowCount = 0
		Begin
			-- Generate an error message stating that no results were found
			exec QuantitationProcessWorkMsgNoResults @QuantitationID, @InternalStdInclusionMode, @message output
			set @myError = 123
			goto Done
		End


		--
		-- Step 5g - Compute ER_Recomputed (Sum of light member of all UMCs for each mass tag divided by sum of heavy member of all UMCs for each mass tag)
		--
		UPDATE #UMCMatchResultsByJob
		SET ER_Recomputed = MTAbundanceLight / MTAbundanceHeavy
		WHERE MTAbundanceHeavy > 0
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error while recomputing the Expression Ratio in the #UMCMatchResultsByJob temporary table'
			Set @myError = 124
			Goto Done
		End

		-- Copy the ER value into ER_ToUse
		If @ERMode = 0
		  Begin
			UPDATE #UMCMatchResultsByJob
			SET ER_ToUse = ER_Recomputed
		  End
		Else
		  Begin
			UPDATE #UMCMatchResultsByJob
			SET ER_ToUse = ER_WeightedAvg
		  End

		
		--
		-- Step 5h - Possibly delete hits that match mass tags with too low of a High_Normalized_Score
		--           or discriminant score or PMT Quality Score value
		--
		If @MinimumMTHighNormalizedScore > 0 OR 
		   @MinimumMTHighDiscriminantScore > 0 OR 
		   @MinimumMTPeptideProphetProbability > 0 OR 
		   @MinimumPMTQualityScore > 0
		Begin
			DELETE FROM #UMCMatchResultsByJob
			WHERE InternalStdMatch = 0 AND 
				  (
					PMT_Quality_Score < @MinimumPMTQualityScore OR
					High_Normalized_Score < @MinimumMTHighNormalizedScore OR
					High_Discriminant_Score < @MinimumMTHighDiscriminantScore OR
					High_Peptide_Prophet_Probability < @MinimumMTPeptideProphetProbability
				  )
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount
			--
			If @myError <> 0
			Begin
				Set @message = 'Error removing the low score mass tags from the #UMCMatchResultsByJob temporary table'
				Set @myError = 125
				Goto Done
			End		
			--
			If @myRowCount > 0
			Begin
				SELECT @myRowCount = Count(*) FROM #UMCMatchResultsByJob
				--
				If @myRowCount = 0
				Begin
					-- Post an error message to T_Log_Entries
					set @message = 'All matching mass tags were filtered out by the Minimum MT High Normalized Score or Minimum PMT Quality Score for Quantitation_ID = ' + convert(varchar(19), @QuantitationID) + ' listed in T_Quantitation_MDIDs'
					set @myError = 126
					goto Done
				End
			End
		End

		--
		-- Step 5i - Possibly delete hits that match mass tags with peptide sequences that are too short
		--
		If @MinimumPeptideLength > 0
		Begin
			-- Transact-SQL delete notation
			DELETE #UMCMatchResultsByJob
			FROM #UMCMatchResultsByJob INNER JOIN 
				 T_Mass_Tags AS MT ON #UMCMatchResultsByJob.Mass_Tag_ID = MT.Mass_Tag_ID
			WHERE Len(MT.Peptide) < @MinimumPeptideLength
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount
			--
			If @myError <> 0 
			Begin
				Set @message = 'Error removing the short peptides from the #UMCMatchResultsByJob temporary table'
				Set @myError = 127
				Goto Done
			End		
			--
			If @myRowCount > 0
			Begin
				SELECT @myRowCount = Count(*) FROM #UMCMatchResultsByJob
				--
				If @myRowCount = 0
				Begin
					-- Post an error message to T_Log_Entries
					set @message = 'All matching mass tags were filtered out by the Minimum Peptide Length value for Quantitation_ID = ' + convert(varchar(19), @QuantitationID) + ' listed in T_Quantitation_MDIDs'
					set @myError = 128
					goto Done
				End
			End
		End
		
		
		--
		-- Step 5j
		--
		-- Determine the percent of UMCs that matched just one mass tag (i.e. percent that had a unique match)
		-- In order to reflect larger UMCs that had a single match, we compute the percentage using:
		--  [Total number of matching ions (scans) in the UMC's for each mass tag wherein the UMC has MassTag_HitCount = 1]
		--	 divided by
		--  [Total number of matching ions (scans) in all UMC's for this mass tag]
		--

		-- The above two values are stored in UMCIonCountMatchInUMCsWithSingleHit and UMCIonCountMatch
		--  in the #UMCMatchResultsByJob temporary table, and were already obtained
		--  in the above Insert Into query.
		--	
		UPDATE #UMCMatchResultsByJob
		SET FractionScansMatchingSingleMT = 
			Convert(float, IsNull(UMCIonCountMatchInUMCsWithSingleHit, 0)) / 
			Convert(float, UMCIonCountMatch)
		WHERE UMCIonCountMatch > 0

		--
		-- Step 5k
		--
		-- Update Observed_By_MSMS_in_This_Dataset by looking for Sequest or XTandem results
		-- from the datasets corresponding to the jobs in #UMCMatchResultsByJob
		
		Declare @CheckResultsInRemotePeptideDBs tinyint
		Set @CheckResultsInRemotePeptideDBs = 1

		SELECT @CheckResultsInRemotePeptideDBs = Enabled
		FROM T_Process_Step_Control
		WHERE Processing_Step_Name = 'QR_Check_Results_in_Remote_Peptide_DBs'
		
		Exec @myError = QuantitationProcessCheckForMSMSPeptideIDs @CheckResultsInRemotePeptideDBs, 
									@MinimumMTHighNormalizedScore = @MinimumMTHighNormalizedScore,
									@MinimumMTHighDiscriminantScore = @MinimumMTHighDiscriminantScore,
									@MinimumMTPeptideProphetProbability = @MinimumMTPeptideProphetProbability,
									@MinimumPMTQualityScore = @MinimumPMTQualityScore,
									@message = @message output

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'QuantitationProcessWorkStepB')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output
	End Catch	
	
Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessWorkStepB] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessWorkStepB] TO [MTS_DB_Lite]
GO
