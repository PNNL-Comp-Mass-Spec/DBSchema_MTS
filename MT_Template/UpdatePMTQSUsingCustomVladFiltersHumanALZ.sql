-- UpdatePMTQSUsingCustomTaoFilters is in these DBs:
--   MT_Human_EIF_NAF_P328
--   MT_Human_Schutzer_CSF_P420
--   MT_Human_Schutzer_CSF_P512
--   MT_D_Melanogaster_NCI_P531
--	 MT_Human_BreastCancer_WRI_P582
--
-- UpdatePMTQSUsingCustomVladFilters            is in DB MT_Mouse_Voxel_P477
-- UpdatePMTQSUsingCustomVladFiltersHumanALZ is in DB MT_Human_ALZ_P514


ALTER PROCEDURE UpdatePMTQSUsingCustomVladFiltersHumanALZ
/****************************************************
** 
**	Desc:	Updates the PMT Quality Score values for the MTs in this database
**			using filters provided by Vlad Petyuk.  This procedure uses the
**			data in T_User_DatasetID_Scan_MH to lookup the Parent ion MH values for
**			a given scan.
**
**			This procedure is similar to UpdatePMTQSUsingCustomVladFilters, but it
**			has new values specific for DB MT_Human_ALZ_P514.  It also includes
**			experiment filters
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	11/25/2008
**			03/20/2009 mem - Expanded the filter criteria to include Experiment and CleavageState
**    
*****************************************************/
(
	@InfoOnly tinyint = 0,
	@PreviewSql tinyint = 0,
	@message varchar(255) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @ExperimentFilter varchar(128)
	declare @ChargeState smallint
	declare @DeltaMassPPM real
	declare @XCorr real
	declare @DeltaCN2 real
	Declare @CleavageState smallint
	declare @PMTQS real
	declare @EntryID int
	
	Declare @ProtonMass float
	Set @ProtonMass = 1.007276
	
	Declare @Continue tinyint
	
	declare @S varchar(2048)
	
	-------------------------------------------------------------
	-- Validate the inputs
	-------------------------------------------------------------
	
	Set @InfoOnly = IsNull(@InfoOnly, 0)
	Set @PreviewSql = IsNull(@PreviewSql, 0)
	Set @message = ''

	--------------------------------------------------------------
	-- Create a temporary table to hold the scores to filter on
	--------------------------------------------------------------

	CREATE TABLE #TmpNewMassTagScores (
		Mass_Tag_ID int,
		PMT_Quality_Score real,
		Filter_Match_Count int
	)
	
	CREATE UNIQUE INDEX #IX_NewMassTagScores ON #TmpNewMassTagScores (Mass_Tag_ID ASC)
	
	
	CREATE TABLE #TmpFilterScores (
		ExperimentFilter varchar(128),			-- Like Clause text to match against Experiment name
		ChargeState smallint,
		DeltaMassPPM real,
		XCorr real,
		DeltaCN2 real,
		CleavageState smallint,					-- Exact cleavage state to match
		PMTQS real,
		MT_Match_Count int,
		Entry_ID int Identity(1,1)
	)
	
	--------------------------------------------------------------
	-- Populate #TmpFilterScores
	--------------------------------------------------------------

	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][1-9]%',  1, 2  , 0.6, 0.06, 2, 1   , 0) -- 10% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][1-9]%',  1, 3  , 1  , 0.1 , 2, 1.5 , 0) -- 3.16% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][1-9]%',  1, 3  , 1.4, 0.1 , 2, 2   , 0) -- 1% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][1-9]%',  1, 0  , 100, 100 , 2, 2.5 , 0) -- 0.316% FDR

	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][1-9]%',  2, 3.5, 1.3, 0   , 2, 1   , 0) -- 10% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][1-9]%',  2 , 2.5, 1.4, 0.06, 2, 1.5 , 0) -- 3.16% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][1-9]%',  2, 2  , 1.5, 0.11, 2, 2   , 0) -- 1% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][1-9]%',  2, 2.5, 1.9, 0.16, 2, 2.5 , 0) -- 0.316% FDR

	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][1-9]%',  3, 3  , 1.6, 0.03, 2, 1   , 0) -- 10% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][1-9]%',  3, 2.5, 1.9, 0.07, 2, 1.5 , 0) -- 3.16% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][1-9]%',  3, 2  , 2  , 0.12, 2, 2   , 0) -- 1% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][1-9]%',  3, 1.5, 2.3, 0.13, 2, 2.5 , 0) -- 0.316% FDR

	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][1-9]%',  4, 3.5, 1.8, 0.02, 2, 1   , 0) -- 10% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][1-9]%',  4, 3  , 2.2, 0.07, 2, 1.5 , 0) -- 3.16% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][1-9]%',  4, 2.5, 1.4, 0.17, 2, 2   , 0) -- 1% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][1-9]%',  4, 1.5, 0  , 0.19, 2, 2.5 , 0) -- 0.316% FDR


	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][_]SCX%', 1, 4  , 1.9, 0.03, 2, 1   , 0) -- 10% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][_]SCX%', 1, 3.5, 1.4, 0.05, 2, 1.5 , 0) -- 3.16% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][_]SCX%', 1, 6  , 1.6, 0.11, 2, 2   , 0) -- 1% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][_]SCX%', 1, 3  , 1.8, 0.1 , 2, 2.5 , 0) -- 0.316% FDR
	
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][_]SCX%', 2, 4.5, 1.5, 0   , 2, 1   , 0) -- 10% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][_]SCX%', 2, 4  , 1.7, 0.07, 2, 1.5 , 0) -- 3.16% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][_]SCX%', 2, 3  , 1.8, 0.13, 2, 2   , 0) -- 1% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][_]SCX%', 2, 3  , 2.1, 0.17, 2, 2.5 , 0) -- 0.316% FDR
	
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][_]SCX%', 3, 3.5, 1.7, 0.02, 2, 1   , 0) -- 10% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][_]SCX%', 3, 3  , 2  , 0.07, 2, 1.5 , 0) -- 3.16% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][_]SCX%', 3, 3  , 2  , 0.16, 2, 2   , 0) -- 1% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][_]SCX%', 3, 3  , 2.5, 0.16, 2, 2.5 , 0) -- 0.316% FDR
	
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][_]SCX%', 4, 3.5, 1.8, 0.04, 2, 1   , 0) -- 10% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][_]SCX%', 4, 2.5, 2  , 0.1 , 2, 1.5 , 0) -- 3.16% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][_]SCX%', 4, 3.5, 2.2, 0.18, 2, 2   , 0) -- 1% FDR
	INSERT INTO #TmpFilterScores VALUES ('ALZ_VP2P101[_][C-D][_]SCX%', 4, 2.5, 2.1, 0.23, 2, 2.5 , 0) -- 0.316% FDR



	--------------------------------------------------------------
	-- Populate #TmpNewMassTagScores
	--------------------------------------------------------------
	
	INSERT INTO #TmpNewMassTagScores (Mass_Tag_ID, PMT_Quality_Score, Filter_Match_Count)
	SELECT Mass_Tag_ID, 0, 0
	FROM T_Mass_Tags
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	--------------------------------------------------------------
	-- Loop through the entries in #TmpFilterScores
	--------------------------------------------------------------
	
	Set @EntryID = 0
	
	Set @Continue = 1
	While @Continue = 1
	Begin -- <a>
		SELECT TOP 1	@ExperimentFilter = ExperimentFilter,
						@ChargeState = ChargeState,
						@DeltaMassPPM = DeltaMassPPM,
						@XCorr = XCorr,
						@DeltaCN2 = DeltaCN2,
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
		Begin -- <b>
		
			UPDATE #TmpNewMassTagScores
			SET PMT_Quality_Score = CASE WHEN @PMTQS > PMT_Quality_Score THEN @PMTQS ELSE PMT_Quality_Score END,
				Filter_Match_Count = Filter_Match_Count + 1
			FROM #TmpNewMassTagScores NMTS INNER JOIN
				(   SELECT DISTINCT Mass_Tag_ID
					FROM ( SELECT	Pep.Mass_Tag_ID,
									DSMH.Parent_MH,
									MT.Monoisotopic_Mass + @ProtonMass AS Peptide_MH
							FROM T_User_DatasetID_Scan_MH DSMH
								INNER JOIN T_Peptides Pep
									ON DSMH.Scan_Number = Pep.Scan_Number 
										AND
										DSMH.Charge_State = Pep.Charge_State
								INNER JOIN T_Analysis_Description TAD
									ON Pep.Analysis_ID = TAD.Job AND
										DSMH.Dataset_ID = TAD.Dataset_ID
								INNER JOIN T_Mass_Tags MT
									ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID
								INNER JOIN T_Score_Sequest SS
									ON Pep.Peptide_ID = SS.Peptide_ID
							WHERE TAD.Experiment LIKE @ExperimentFilter AND
							      Pep.Charge_State = @ChargeState AND
								  SS.XCorr >= @XCorr AND
								  SS.DeltaCN2 >= @DeltaCN2 AND
								  MT.Cleavage_State_Max = @CleavageState
						  ) LookupQ
					WHERE (ABS((Parent_MH - Peptide_MH) / Peptide_MH * 1e6) <= @DeltaMassPPM ) 
				) FilterQ ON NMTS.Mass_Tag_ID = FilterQ.Mass_Tag_ID			
          	--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			-- Track the number of matching peptides using #TmpFilterScores
			UPDATE #TmpFilterScores
			SET MT_Match_Count = @myRowCount
			WHERE Entry_ID = @EntryID			
		
		End -- </b>

	End -- </a>
	
	If @InfoOnly <> 0
	Begin
		-- Display the contents of #TmpFilterScores
		--
		SELECT Entry_ID,
		       ExperimentFilter,
		       ChargeState,
		       DeltaMassPPM,
		       XCorr,
		       DeltaCN2,
		       CleavageState,
		       PMTQS,
		       MT_Match_Count
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
	End
	Else
	Begin
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

	End
		
	
Done:
	return @myError

GO