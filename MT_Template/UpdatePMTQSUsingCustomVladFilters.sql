-- UpdatePMTQSUsingCustomTaoFilters is in these DBs:
--   MT_Human_EIF_NAF_P328           on Elmer
--   MT_Human_Schutzer_CSF_P420      on Elmer
--   MT_Human_Schutzer_CSF_P512      on Elmer
--   MT_D_Melanogaster_NCI_P531      on Albert
--	 MT_Human_BreastCancer_WRI_P582  on Elmer
--   MT_S_cerevisiae_UPS_P641        on Daffy	(filters on Dataset names instead of Experiment names)
--
-- UpdatePMTQSUsingCustomVladFilters is in these DBs
--   MT_Mouse_Voxel_P477 on Pogo (code is in UpdatePMTQSUsingCustomVladFiltersMouseVoxel.sql)
--   MT_C_Elegans_P618 on Albert
--	 MT_Human_ALZ_Phospho_P720 (extended to use ParamFileFilter and ModSymbolFilter)
--	 MT_Human_Sarcopenia_P652 on Elmer
--	 MT_Human_Sarcopenia_P676 on Elmer
--	 MT_Human_Sarcopenia_MixedLC_P681 on Elmer
--	 MT_Human_Sarcopenia_MixedLC_P692 on Elmer
--   MT_Human_Sarcopenia_P724 on Elmer (extended to use MSGF_SpecProb)
--   MT_Human_HMEC_EGFR_P706 on Elmer
--   MT_S_oneidensis_MR1_P777 on Daffy (uses MSGF_SpecProb and T_Peptides.DelM_PPM)
--   MT_Mouse_CHF_P776 on Pogo  (uses MSGF_SpecProb and T_Peptides.DelM_PPM)
--   MT_Human_ALZ_O18_P836
--   MT_Mouse_MHP_Unlabeled_P929 on Pogo  (uses MSGF_SpecProb and T_Peptides.DelM_PPM; also filters on PSM_Count)
--   MT_Mouse_MHP_Unlabeled_P933 on Pogo  (uses MSGF_SpecProb and T_Peptides.DelM_PPM)
--   MT_Human_LewyBody_P947 on Proteinseqs  (uses MSGF_SpecProb and T_Peptides.DelM_PPM; also filters on Dataset_Count)
--   MT_Human_LewyBody_P1010 on Proteinseqs (uses MSGF_SpecProb and T_Peptides.DelM_PPM)
--   MT_Human_LewyBody_P1011 on Proteinseqs (uses MSGF_SpecProb and T_Peptides.DelM_PPM)
--   MT_Human_LewyBody_P1012 on Proteinseqs (uses MSGF_SpecProb and T_Peptides.DelM_PPM)
--
-- UpdatePMTQSUsingCustomVladFiltersHumanALZ is in MT_Human_ALZ_P514 on Elmer
--
-- CheckFilterUsingCustomCriteria is used in PT_Human_ALZ_Phospho_A235
--
-- UpdatePMTQSUsingCustomFilters is in these DBs
--   MT_Human_Glycated_Peptides_P742 (extended to use Peptide_Prophet_Probability to consider terminus_state)

SET QUOTED_IDENTIFIER ON
SET ANSI_PADDING ON
GO

CREATE TABLE [dbo].[T_Custom_PMT_QS_Criteria_VP](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	PMTQS real NOT NULL,
	ExperimentFilter varchar(128) NOT NULL default '',
	ParamFileFilter varchar(255) NOT NULL default '',
	ChargeState smallint NOT NULL,
	DeltaMassPPM real NOT NULL,
	XCorr real NOT NULL,
	DeltaCN2 real NOT NULL,
	ModSymbolFilter varchar(12) NOT NULL default '',
	MSGF_SpecProb real NOT NULL,
	CleavageState smallint NOT NULL,
    PSM_Count smallint NOT NULL,
	Dataset_Count smallint NOT NULL
 CONSTRAINT [PK_T_Custom_PMT_QS_Criteria_VP] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

SET ANSI_PADDING ON
GO

CREATE UNIQUE NONCLUSTERED INDEX [IX_T_Custom_PMT_QS_Criteria_VP] ON [dbo].[T_Custom_PMT_QS_Criteria_VP] 
(
	PMTQS,
	ExperimentFilter ASC,
	ParamFileFilter,
	ModSymbolFilter,
	ChargeState, 
	CleavageState
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO


GO

ALTER PROCEDURE dbo.UpdatePMTQSUsingCustomVladFilters
/****************************************************
** 
**	Desc:	Updates the PMT Quality Score values for the MTs in this database
**			using filters provided by Vlad Petyuk.
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	11/25/2008
**			03/20/2009 mem - Expanded the filter criteria to include Experiment and CleavageState
**			05/06/2010 mem - Updated to read the filter values from table T_Custom_PMT_QS_Criteria_VP
**						   - Removed dependency on table T_User_DatasetID_Scan_MH
**			08/25/2011 mem - Added column MSGF_SpecProb
**			09/19/2011 mem - Added columns ParamFileFilter and ModSymbolFilter
**			02/09/2012 mem - Updated to use T_Peptides.DelM_PPM
**						   - Updated to left outer join to T_Score_Sequest
**						   - Updated to use T_Peptides.Job
**			11/26/2013 mem - Now filtering on Number_of_Peptides if PSM_Count is > 0 in T_Custom_PMT_QS_Criteria_VP
**			02/21/2014 mem - Now filtering on PMT_Quality_Score_Local if Dataset_Count is > 0 (requires that ComputePMTQualityScoreLocal be enabled)
**    
*****************************************************/
(
	@InfoOnly tinyint = 0,
	@message varchar(255) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @ExperimentFilter varchar(128)
	declare @ParamFileFilter varchar(255)
	declare @ChargeState smallint
	declare @DeltaMassPPM real
	declare @XCorr real
	declare @DeltaCN2 real
	declare @ModSymbolFilter varchar(12)
	declare @ModSymbolExclusionFilter varchar(12)
	declare @MSGFSpecProb real
	declare @CleavageState smallint
	declare @PMTQS real
	declare @EntryID int
	
	Declare @ProtonMass float
	Set @ProtonMass = 1.007276
	
	Declare @Continue tinyint
	Declare @UpdatePMTScoreLocal tinyint = 0
	
	-------------------------------------------------------------
	-- Validate the inputs
	-------------------------------------------------------------
	
	Set @InfoOnly = IsNull(@InfoOnly, 0)
	Set @message = ''

	--------------------------------------------------------------
	-- Create temporary tables that will track the new PMT Quality Score values to store
	--------------------------------------------------------------

	CREATE TABLE #TmpNewMassTagScores (
		Mass_Tag_ID int,
		PMT_Quality_Score real,
		Filter_Match_Count int
	)
	
	CREATE UNIQUE INDEX #IX_NewMassTagScores ON #TmpNewMassTagScores (Mass_Tag_ID ASC)
	
	CREATE TABLE #TmpNewPeptideScores (
		Peptide_ID int,
		PMT_Quality_Score_Local real,
		Filter_Match_Count int
	)
	
	CREATE UNIQUE INDEX #IX_NewPeptideScores ON #TmpNewPeptideScores (Peptide_ID ASC)

	--------------------------------------------------------------
	-- Create a temporary table to hold the scores to filter on
	--------------------------------------------------------------
	
	CREATE TABLE #TmpFilterScores (
		Entry_ID int, 
		ExperimentFilter varchar(128),			-- Like Clause text to match against Experiment name; use '%' to match all experiments
		ParamFileFilter varchar(255),			-- Empty means any parameter file; otherwise, a Like clause to compare to the Parameter_File_Name column in T_Analysis_Description
		ChargeState smallint,
		DeltaMassPPM real,
		XCorr real,
		DeltaCN2 real,
		ModSymbolFilter varchar(12),			-- Empty field means the criteria apply to any peptide; 'NoMods' means they only apply to peptides without a mod symbol; '*' means they only apply to peptides with a * in the residues
		MSGF_SpecProb real,
		CleavageState smallint,					-- Exact cleavage state to match; set to -1 to match all cleavage states
		PMTQS real,
		MT_Match_Count int,
		Peptide_Match_Count int
	)
	
	--------------------------------------------------------------
	-- Populate #TmpFilterScores
	--------------------------------------------------------------

	INSERT INTO #TmpFilterScores( Entry_ID,
	      ExperimentFilter,
	                              ParamFileFilter,
	                              ChargeState,
	                              DeltaMassPPM,
	                              XCorr,
	                              DeltaCN2,
	                              ModSymbolFilter,
	                              MSGF_SpecProb,
	                              CleavageState,
	                              PMTQS,
	                              MT_Match_Count,
	                              Peptide_Match_Count)
	SELECT Entry_ID,
	       ExperimentFilter,
	       ParamFileFilter,
	       ChargeState,
	       DeltaMassPPM,
	       XCorr,
	       DeltaCN2,
	       ModSymbolFilter,
	       MSGF_SpecProb,
	       CleavageState,
	       PMTQS,
	       0 AS MT_Match_Count,
	       0 AS Peptide_Match_Count
	FROM T_Custom_PMT_QS_Criteria_VP
    ORDER BY Entry_ID
    
	--------------------------------------------------------------
	-- Populate #TmpNewMassTagScores
	--------------------------------------------------------------
	
	INSERT INTO #TmpNewMassTagScores (Mass_Tag_ID, PMT_Quality_Score, Filter_Match_Count)
	SELECT Mass_Tag_ID, 0, 0
	FROM T_Mass_Tags
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	--------------------------------------------------------------
	-- Look for PMT_Quality_Score_Local values in T_Peptides
	-- If they are defined, then they will also be updated
	--------------------------------------------------------------
	--
	If Exists (Select * FROM T_Peptides WHERE PMT_Quality_Score_Local > 0)
	Begin
		Set @UpdatePMTScoreLocal = 1
		
		INSERT INTO #TmpNewPeptideScores (Peptide_ID, PMT_Quality_Score_Local, Filter_Match_Count)
		SELECT Peptide_ID, 0, 0
		FROM T_Peptides
	End


	--------------------------------------------------------------
	-- Loop through the entries in #TmpFilterScores
	--------------------------------------------------------------
	
	Set @EntryID = 0
	
	Set @Continue = 1
	While @Continue = 1
	Begin -- <a1>
		SELECT TOP 1	@ExperimentFilter = ExperimentFilter,
						@ParamFileFilter = ParamFileFilter,
						@ChargeState = ChargeState,
						@DeltaMassPPM = DeltaMassPPM,
						@XCorr = XCorr,
						@DeltaCN2 = DeltaCN2,
						@ModSymbolFilter = ModSymbolFilter,
						@MSGFSpecProb = MSGF_SpecProb,
						@CleavageState = CleavageState,
						@PMTQS = PMTQS,
						@EntryID = Entry_ID 
		FROM #TmpFilterScores
		WHERE Entry_ID > @EntryID
		ORDER BY Entry_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @Continue = 0
		Else
		Begin -- <b1>
		
			If IsNull(@ExperimentFilter, '') = ''
				Set @ExperimentFilter = '%'

			If IsNull(@ParamFileFilter, '') = ''
				Set @ParamFileFilter = '%'
			
			If ISNULL(@ModSymbolFilter, '') = ''
				Set @ModSymbolFilter = ''				
			
			If @ModSymbolFilter Like 'Not[ ]%' And Len(@ModSymbolFilter) >= 5
			Begin
				Set @ModSymbolExclusionFilter = SUBSTRING(@ModSymbolFilter, 5, 100)
				Set @ModSymbolFilter = ''
			End
			Else
				Set @ModSymbolExclusionFilter = ''

			
			UPDATE #TmpNewMassTagScores
			SET PMT_Quality_Score = CASE WHEN @PMTQS > PMT_Quality_Score THEN @PMTQS ELSE PMT_Quality_Score END,
				Filter_Match_Count = Filter_Match_Count + 1
			FROM #TmpNewMassTagScores NMTS INNER JOIN
				(   SELECT DISTINCT Mass_Tag_ID
					FROM ( SELECT	Pep.Mass_Tag_ID,
					                Pep.DelM_PPM
							FROM T_Peptides Pep
								INNER JOIN T_Analysis_Description TAD
									ON Pep.Job = TAD.Job
								INNER JOIN T_Mass_Tags MT
									ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID
                                INNER JOIN T_Score_Discriminant SD
									ON Pep.Peptide_ID = SD.Peptide_ID
								LEFT OUTER JOIN T_Score_Sequest SS
								    ON Pep.Peptide_ID = SS.Peptide_ID
							WHERE TAD.Experiment LIKE @ExperimentFilter AND
							      TAD.Parameter_File_Name LIKE @ParamFileFilter AND
							      Pep.Charge_State = @ChargeState AND
								  ISNULL(SS.XCorr, 0) >= @XCorr AND
								  ISNULL(SS.DeltaCN2, 0) >= @DeltaCN2 AND
                                  SD.MSGF_SpecProb <= @MSGFSpecProb AND
								  (@CleavageState < 0 Or MT.Cleavage_State_Max = @CleavageState) AND
							      (
							        (@ModSymbolFilter = '') OR 
									(@ModSymbolFilter = 'NoMods' And Not Pep.Peptide Like '%[*#@!$%^&]%') OR 
									(Len(@ModSymbolFilter) > 0 AND @ModSymbolFilter <> 'NoMods' And Pep.Peptide Like '%' + @ModSymbolFilter + '%') 
							      ) AND
							      (
									(@ModSymbolExclusionFilter = '') OR
									(Len(@ModSymbolExclusionFilter) > 0 AND Not MT.Mod_Description Like '%' + @ModSymbolExclusionFilter + '%') 
							      )
						  ) LookupQ
					WHERE (ABS(DelM_PPM) <= @DeltaMassPPM ) 
				) FilterQ ON NMTS.Mass_Tag_ID = FilterQ.Mass_Tag_ID
          	--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			-- Track the number of matching AMT tags using #TmpFilterScores
			UPDATE #TmpFilterScores
			SET MT_Match_Count = @myRowCount
			WHERE Entry_ID = @EntryID			

					
			If @UpdatePMTScoreLocal > 0
			Begin
			
				UPDATE #TmpNewPeptideScores
				SET PMT_Quality_Score_Local = CASE WHEN @PMTQS > PMT_Quality_Score_Local THEN @PMTQS ELSE PMT_Quality_Score_Local END,
					Filter_Match_Count = Filter_Match_Count + 1
				FROM #TmpNewPeptideScores NPS INNER JOIN
					(   SELECT Peptide_ID
						FROM ( SELECT	Pep.Peptide_ID,
										Pep.DelM_PPM
								FROM T_Peptides Pep
									INNER JOIN T_Analysis_Description TAD
										ON Pep.Job = TAD.Job
									INNER JOIN T_Mass_Tags MT
										ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID
									INNER JOIN T_Score_Discriminant SD
										ON Pep.Peptide_ID = SD.Peptide_ID
									LEFT OUTER JOIN T_Score_Sequest SS
										ON Pep.Peptide_ID = SS.Peptide_ID
								WHERE TAD.Experiment LIKE @ExperimentFilter AND
									  TAD.Parameter_File_Name LIKE @ParamFileFilter AND
									  Pep.Charge_State = @ChargeState AND
									  ISNULL(SS.XCorr, 0) >= @XCorr AND
									  ISNULL(SS.DeltaCN2, 0) >= @DeltaCN2 AND
									  SD.MSGF_SpecProb <= @MSGFSpecProb AND
									  (@CleavageState < 0 Or MT.Cleavage_State_Max = @CleavageState) AND
									  (
										(@ModSymbolFilter = '') OR 
										(@ModSymbolFilter = 'NoMods' And Not Pep.Peptide Like '%[*#@!$%^&]%') OR 
										(Len(@ModSymbolFilter) > 0 AND @ModSymbolFilter <> 'NoMods' And Pep.Peptide Like '%' + @ModSymbolFilter + '%') 
									  ) AND
									  (
										(@ModSymbolExclusionFilter = '') OR
										(Len(@ModSymbolExclusionFilter) > 0 AND Not MT.Mod_Description Like '%' + @ModSymbolExclusionFilter + '%') 
									  )
							) LookupQ
						WHERE (ABS(DelM_PPM) <= @DeltaMassPPM ) 
					) FilterQ ON NPS.Peptide_ID = FilterQ.Peptide_ID
          		--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				-- Track the number of matching peptides using #TmpFilterScores
				UPDATE #TmpFilterScores
				SET Peptide_Match_Count = @myRowCount
				WHERE Entry_ID = @EntryID			
			End
						
		End -- </b1>

	End -- </a1>
	
	If @InfoOnly <> 0
	Begin -- <a2>
		-- Display the contents of #TmpFilterScores
		--
		SELECT *
		FROM #TmpFilterScores
		ORDER BY Entry_ID
		
		-- Show the first 50 entries in #TmpNewMassTagScores
		--
		SELECT TOP 50 NMTS.Mass_Tag_ID,
		              MT.PMT_Quality_Score AS PMT_QS_Old,
		              NMTS.PMT_Quality_Score AS PMT_QS_New,
		              NMTS.Filter_Match_Count
		FROM T_Mass_Tags MT
		     INNER JOIN #TmpNewMassTagScores NMTS
		       ON MT.Mass_Tag_ID = NMTS.Mass_Tag_ID
		ORDER BY NMTS.Mass_Tag_ID
		
		If @UpdatePMTScoreLocal > 0
		Begin
			-- Show the first 500 entries in #TmpNewPeptideScores
			--
			SELECT TOP 500 NPS.Peptide_ID,
						Pep.Mass_Tag_ID,
						Pep.PMT_Quality_Score_Local AS PMT_QS_Local_Old,
						NPS.PMT_Quality_Score_Local AS PMT_QS_Local_New,
						NPS.Filter_Match_Count
			FROM T_Peptides Pep
				INNER JOIN #TmpNewPeptideScores NPS
				ON Pep.Peptide_ID = NPS.Peptide_ID
			ORDER BY NPS.Peptide_ID
		End
		
	End -- </a2>
	Else
	Begin -- <a3>
		-- Store the new PMT Quality Score values
		--
		UPDATE T_Mass_Tags
		SET PMT_Quality_Score = NMTS.PMT_Quality_Score
		FROM T_Mass_Tags MT
		     INNER JOIN #TmpNewMassTagScores NMTS
		       ON MT.Mass_Tag_ID = NMTS.Mass_Tag_ID
		WHERE MT.PMT_Quality_Score <> NMTS.PMT_Quality_Score
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		-- Log the change
		Set @message = 'Updated the PMT_Quality_Score values in T_Mass_Tags using custom tolerances based on Experiment, Charge State, DeltaMass (ppm), XCorr, DeltaCN2, and Cleavage State; Updated scores for ' + Convert(varchar(12), @myRowCount) + ' AMTs'
		
		execute PostLogEntry 'Normal', @message, 'UpdatePMTQSUsingCustomVladFilters'

		If @UpdatePMTScoreLocal > 0
		Begin
			UPDATE T_Peptides
			SET PMT_Quality_Score_Local = NPS.PMT_Quality_Score_Local
			FROM T_Peptides PT
			     INNER JOIN #TmpNewPeptideScores NPS
			       ON PT.Peptide_ID = NPS.Peptide_ID
			WHERE PT.PMT_Quality_Score_Local <> NPS.PMT_Quality_Score_Local
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			-- Log the change
			Set @message = 'Updated the PMT_Quality_Score_Local values in T_Peptides using custom tolerances based on Experiment, Charge State, DeltaMass (ppm), XCorr, DeltaCN2, and Cleavage State; Updated scores for ' + Convert(varchar(12), @myRowCount) + ' Peptides'
			
			execute PostLogEntry 'Normal', @message, 'UpdatePMTQSUsingCustomVladFilters'
		End


		Declare @PMTQSIterator int

		If Exists (Select * from T_Custom_PMT_QS_Criteria_VP Where PSM_Count > 0)
		Begin -- <b2>
			
			Declare @PSMCountMax int
			
			Set @PMTQSIterator = 1000
			While @PMTQSIterator > 0
			Begin -- <c2>
				SELECT TOP 1 @PMTQSIterator = PMTQS,
				             @PSMCountMax = PSM_Count_Max
				FROM ( SELECT PMTQS,
				              MAX(PSM_Count) AS PSM_Count_Max
				       FROM T_Custom_PMT_QS_Criteria_VP
				       WHERE PMTQS < @PMTQSIterator
				       GROUP BY PMTQS
				       HAVING MAX(PSM_Count) > 0
				      ) LookupQ
				ORDER BY PMTQS DESC
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				If @myRowCount = 0
				Begin
					Set @PMTQSIterator = 0
				End
				Else
				Begin -- <d1>
				
					UPDATE T_Mass_Tags
					SET PMT_Quality_Score = PMT_Quality_Score - 1
					WHERE PMT_Quality_Score = @PMTQSIterator AND
					      Number_Of_Peptides < @PSMCountMax
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
				
					If @myRowCount > 0
					Begin
						Set @message = 'Decremented PMT_Quality_Score for ' + Convert(varchar(12), @myRowCount) + ' AMTs with PMT_QS ' + Convert(varchar(12), @PMTQSIterator) + ' but Number_Of_Peptides < ' + Convert(varchar(12), @PSMCountMax)
						execute PostLogEntry 'Normal', @message, 'UpdatePMTQSUsingCustomVladFilters'
					End
					
				End -- </d1>
			End -- </c2>
			
		End -- </b2>
		
		
		If Exists (Select * from T_Custom_PMT_QS_Criteria_VP Where Dataset_Count > 0)
		Begin -- <b3>
		
			-- Make sure PMT_Quality_Score_Local values are defined
			If @UpdatePMTScoreLocal = 0
			Begin
				Set @message = 'PMT_Quality_Score_Local values are not defined in T_Peptides; unable to filter on Dataset_Count'
				execute PostLogEntry 'Error', @message, 'UpdatePMTQSUsingCustomVladFilters'
				Goto Done
			End
			
			Declare @DatasetCountMax int
				
			Set @PMTQSIterator = 1000
			While @PMTQSIterator > 0
			Begin -- <c3>
				SELECT TOP 1 @PMTQSIterator = PMTQS,
								@DatasetCountMax = Dataset_Count_Max
				FROM ( SELECT PMTQS,
								MAX(Dataset_Count) AS Dataset_Count_Max
						FROM T_Custom_PMT_QS_Criteria_VP
						WHERE PMTQS < @PMTQSIterator
						GROUP BY PMTQS
						HAVING MAX(Dataset_Count) > 0
						) LookupQ
				ORDER BY PMTQS DESC
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				If @myRowCount = 0
				Begin
					Set @PMTQSIterator = 0
				End
				Else
				Begin -- <d2>
				
					UPDATE T_Mass_Tags
					SET PMT_Quality_Score = MT.PMT_Quality_Score - 1
					FROM T_Mass_Tags MT
							INNER JOIN ( SELECT MT.Mass_Tag_ID,
												COUNT(DISTINCT TAD.Dataset) AS Dataset_Count
										FROM T_Peptides Pep
											INNER JOIN T_Mass_Tags MT
												ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID
											INNER JOIN T_Analysis_Description TAD
												ON Pep.Job = TAD.Job
										WHERE Pep.PMT_Quality_Score_Local >= @PMTQSIterator AND
											  MT.PMT_Quality_Score = @PMTQSIterator
										GROUP BY MT.Mass_Tag_ID 
									) DatasetCountQ
							ON MT.Mass_Tag_ID = DatasetCountQ.Mass_Tag_ID
					WHERE PMT_Quality_Score = @PMTQSIterator AND
						  DatasetCountQ.Dataset_Count < @DatasetCountMax				
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
				
					If @myRowCount > 0
					Begin
						Set @message = 'Decremented PMT_Quality_Score for ' + Convert(varchar(12), @myRowCount) + ' AMTs with PMT_QS ' + Convert(varchar(12), @PMTQSIterator) + ' but Dataset_Count < ' + Convert(varchar(12), @DatasetCountMax)
						execute PostLogEntry 'Normal', @message, 'UpdatePMTQSUsingCustomVladFilters'
					End
					
				End -- </d2>
			End  -- </c3>
		End -- </b3>

	End -- </a3>

Done:
	return @myError

GO
