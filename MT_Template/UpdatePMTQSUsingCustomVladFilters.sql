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
--	 MT_Human_Sarcopenia_P652 on Elmer
--	 MT_Human_Sarcopenia_P676 on Elmer
--	 MT_Human_Sarcopenia_MixedLC_P681 on Elmer
--   MT_Human_HMEC_EGFR_P706 on Elmer
--
-- UpdatePMTQSUsingCustomVladFiltersHumanALZ is in MT_Human_ALZ_P514 on Elmer
--


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [dbo].[T_Custom_PMT_QS_Criteria_VP](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	ExperimentFilter varchar(128) NOT NULL,
	ChargeState smallint NOT NULL,
	DeltaMassPPM real NOT NULL,
	XCorr real NOT NULL,
	DeltaCN2 real NOT NULL,
	CleavageState smallint NOT NULL,
	PMTQS real NOT NULL
 CONSTRAINT [PK_T_Custom_PMT_QS_Criteria_VP] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO

CREATE UNIQUE NONCLUSTERED INDEX [IX_T_Custom_PMT_QS_Criteria_VP] ON [dbo].[T_Custom_PMT_QS_Criteria_VP] 
(
	ExperimentFilter ASC,
	ChargeState, 
	CleavageState,
	PMTQS
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO


GO

ALTER PROCEDURE dbo.UpdatePMTQSUsingCustomVladFilters
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
**			05/06/2010 mem - Updated to read the filter values from table T_Custom_PMT_QS_Criteria_VP
**						   - Removed dependency on table T_User_DatasetID_Scan_MH
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
		Entry_ID int, 
		ExperimentFilter varchar(128),			-- Like Clause text to match against Experiment name; use '%' to match all experiments
		ChargeState smallint,
		DeltaMassPPM real,
		XCorr real,
		DeltaCN2 real,
		CleavageState smallint,					-- Exact cleavage state to match; set to -1 to match all cleavage states
		PMTQS real,
		MT_Match_Count int
	)
	
	--------------------------------------------------------------
	-- Populate #TmpFilterScores
	--------------------------------------------------------------

	INSERT INTO #TmpFilterScores( Entry_ID,
	                              ExperimentFilter,
	                              ChargeState,
	                              DeltaMassPPM,
	                              XCorr,
	                              DeltaCN2,
	                              CleavageState,
	                              PMTQS,
	                              MT_Match_Count)
	SELECT Entry_ID,
	       ExperimentFilter,
	       ChargeState,
	       DeltaMassPPM,
	       XCorr,
	       DeltaCN2,
	       CleavageState,
	       PMTQS,
	       0 AS MT_Match_Count
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
					                SS.DelM / (MT.Monoisotopic_Mass / 1e6) AS DelM_PPM
							FROM T_Peptides Pep
								INNER JOIN T_Analysis_Description TAD
									ON Pep.Analysis_ID = TAD.Job
								INNER JOIN T_Mass_Tags MT
									ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID
								INNER JOIN T_Score_Sequest SS
									ON Pep.Peptide_ID = SS.Peptide_ID
							WHERE TAD.Experiment LIKE @ExperimentFilter AND
							      Pep.Charge_State = @ChargeState AND
								  SS.XCorr >= @XCorr AND
								  SS.DeltaCN2 >= @DeltaCN2 AND
								  (@CleavageState < 0 Or MT.Cleavage_State_Max = @CleavageState)
						  ) LookupQ
					WHERE (ABS(DelM_PPM) <= @DeltaMassPPM ) 
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
