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

CREATE TABLE [dbo].[T_Custom_PMT_QS_Criteria](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	PMTQS real NOT NULL,
	ExperimentFilter varchar(128) NOT NULL,
	ParamFileFilter varchar(255) NOT NULL,
	Charge_State_Comparison varchar(24) NOT NULL,
	DeltaMassPPM real NOT NULL,
	XCorr real NOT NULL,
	DeltaCN2 real NOT NULL,
	ModSymbolFilter varchar(12) NOT NULL,
	Peptide_Prophet_Probability real NOT NULL,
	MSGF_SpecProb real NOT NULL,
	Cleavage_State_Comparison varchar(24) NOT NULL,
	Terminus_State_Comparison varchar(24) NOT NULL,
 CONSTRAINT [PK_T_Custom_PMT_QS_Criteria] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO

CREATE UNIQUE NONCLUSTERED INDEX [IX_T_Custom_PMT_QS_Criteria] ON [dbo].[T_Custom_PMT_QS_Criteria] 
(
	PMTQS,
	ExperimentFilter ASC,
	ParamFileFilter,
	ModSymbolFilter,
	Charge_State_Comparison, 
	Cleavage_State_Comparison,
	Terminus_State_Comparison
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO


GO

ALTER PROCEDURE dbo.UpdatePMTQSUsingCustomFilters
/****************************************************
** 
**	Desc:	Updates the PMT Quality Score values for the MTs in this database
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
**			10/28/2011 mem - Added columns Peptide_Prophet_Probability
**						   - Updated to use Charge_State_Comparison, Cleavage_State_Comparison, and Terminus_State_Comparison
**			01/06/2012 mem - Updated to use T_Peptides.Job
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
	declare @ParamFileFilter varchar(255)
	declare @ChargeStateComparison varchar(24)
	declare @DeltaMassPPM real
	declare @XCorr real
	declare @DeltaCN2 real
	declare @ModSymbolFilter varchar(12)
	declare @PeptideProphetProb real
	declare @MSGFSpecProb real
	declare @CleavageStateComparison varchar(24)
	declare @TerminusStateComparison varchar(24)
	declare @PMTQS real
	declare @EntryID int
	
	declare @PMTQSText varchar(12)
		
	Declare @ProtonMass float
	Set @ProtonMass = 1.007276
	
	Declare @S varchar(4000)

	Declare @UseTerminusFilter tinyint
	Declare @Continue tinyint

	-------------------------------------------------------------
	-- Validate the inputs
	-------------------------------------------------------------
	
	Set @InfoOnly = IsNull(@InfoOnly, 0)
	Set @previewsql = IsNull(@previewsql, 0)
	Set @message = ''

	If @previewsql <> 0
		Set @InfoOnly=1
		
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
		ParamFileFilter varchar(255),			-- Empty means any parameter file; otherwise, a Like clause to compare to the Parameter_File_Name column in T_Analysis_Description
		Charge_State_Comparison varchar(24),    -- Text-based filter for charge.  Examples are "=1", ">=2", "IN (2,3)"
		DeltaMassPPM real,
		XCorr real,
		DeltaCN2 real,
		ModSymbolFilter varchar(12),			-- Empty field means the criteria apply to any peptide; 'NoMods' means they only apply to peptides without a mod symbol; '*' means they only apply to peptides with a * in the residues
		Peptide_Prophet_Probability real,
		MSGF_SpecProb real,
		Cleavage_State_Comparison varchar(24),    -- Text-based filter for cleavage state.  Examples are ">=0", "=1", ">=1"
		Terminus_State_Comparison varchar(24),    -- Text-based filter for cleavage state.  Examples are ">=0", "=1", ">=1".  Leave blank or set to '>=0' to ignore (and speed up this stored procedure)
		PMTQS real,
		MT_Match_Count int
	)
	
	CREATE TABLE #TerminusTable (
		Mass_Tag_ID int,
		Terminus_State smallint
	)
		
	CREATE UNIQUE INDEX #IX_TerminusTable ON #TerminusTable (Mass_Tag_ID ASC, Terminus_State)
	
	--------------------------------------------------------------
	-- Populate #TmpFilterScores
	--------------------------------------------------------------

	INSERT INTO #TmpFilterScores( Entry_ID,
	                     ExperimentFilter,
	                              ParamFileFilter,
	 Charge_State_Comparison,
	                              DeltaMassPPM,
	                              XCorr,
	                              DeltaCN2,
	                              ModSymbolFilter,
	                              Peptide_Prophet_Probability,
	                              MSGF_SpecProb,
	                              Cleavage_State_Comparison,
	                              Terminus_State_Comparison,
	                              PMTQS,
	                              MT_Match_Count)
	SELECT Entry_ID,
	       ExperimentFilter,
	       ParamFileFilter,
	       Charge_State_Comparison,
	       DeltaMassPPM,
	       XCorr,
	       DeltaCN2,
	       ModSymbolFilter,
	       Peptide_Prophet_Probability,
	       MSGF_SpecProb,
	       Cleavage_State_Comparison,
	       Terminus_State_Comparison,
	       PMTQS,
	       0 AS MT_Match_Count
	FROM T_Custom_PMT_QS_Criteria
    ORDER BY Entry_ID
    
	--------------------------------------------------------------
	-- Populate #TmpNewMassTagScores
	--------------------------------------------------------------
	
	INSERT INTO #TmpNewMassTagScores (Mass_Tag_ID, PMT_Quality_Score, Filter_Match_Count)
	SELECT Mass_Tag_ID, 0, 0
	FROM T_Mass_Tags
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Check whether any of the filters has ProteinTerminal >= 0
	
	If Exists (SELECT *	FROM T_Custom_PMT_QS_Criteria WHERE Len(Terminus_State_Comparison) > 0 AND Terminus_State_Comparison <> '>=0')
	Begin
		Set @S = ''
		Set @S = @S + ' INSERT INTO #TerminusTable (Mass_Tag_ID, Terminus_State)'
		Set @S = @S + ' SELECT DISTINCT Mass_Tag_ID, Terminus_State'
		Set @S = @S + ' FROM T_Mass_Tag_to_Protein_Map'


		If @PreviewSql <> 0
			Print @S
		Else
			Exec (@S)
	End
	
    
	--------------------------------------------------------------
	-- Loop through the entries in #TmpFilterScores
	--------------------------------------------------------------
	
	Set @EntryID = 0
	
	Set @Continue = 1
	While @Continue = 1
	Begin -- <a>
		SELECT TOP 1	@ExperimentFilter = ExperimentFilter,
						@ParamFileFilter = ParamFileFilter,
						@ChargeStateComparison = Charge_State_Comparison,
						@DeltaMassPPM = DeltaMassPPM,
						@XCorr = XCorr,
						@DeltaCN2 = DeltaCN2,
						@ModSymbolFilter = ModSymbolFilter,
						@PeptideProphetProb = Peptide_Prophet_Probability,
						@MSGFSpecProb = MSGF_SpecProb,
						@CleavageStateComparison = Cleavage_State_Comparison,
						@TerminusStateComparison = Terminus_State_Comparison,
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

			-- Check whether the charge, cleavage, or terminus comparisons are just a number
			-- If they are, then prepend with an equals sign
		
			If @ChargeStateComparison Like '[0-9]'
				Set @ChargeStateComparison = '=' + @ChargeStateComparison

			If @CleavageStateComparison Like '[0-9]'
				Set @CleavageStateComparison = '=' + @CleavageStateComparison

			If @TerminusStateComparison Like '[0-9]'
				Set @TerminusStateComparison = '=' + @TerminusStateComparison

			If NOT @TerminusStateComparison IN ('', '>=0', '>= 0')
				Set @UseTerminusFilter = 1
			Else
				Set @UseTerminusFilter = 0
			
			Set @PMTQSText = Convert(varchar(12), @PMTQS)
			
			Set @S = ''
			Set @S = @S + ' UPDATE #TmpNewMassTagScores'
			Set @S = @S + ' SET PMT_Quality_Score = CASE WHEN ' + @PMTQSText + ' > PMT_Quality_Score THEN ' + @PMTQSText + ' ELSE PMT_Quality_Score END, '
			Set @S = @S +     ' Filter_Match_Count = Filter_Match_Count + 1'
			Set @S = @S + ' FROM #TmpNewMassTagScores NMTS INNER JOIN'
			Set @S = @S +     ' (   SELECT DISTINCT Mass_Tag_ID'
			Set @S = @S +         ' FROM ( SELECT Pep.Mass_Tag_ID, SS.DelM / (MT.Monoisotopic_Mass / 1e6) AS DelM_PPM'
			Set @S = @S +                ' FROM T_Peptides Pep'
			Set @S = @S +                     ' INNER JOIN T_Analysis_Description TAD'
			Set @S = @S +                         ' ON Pep.Job = TAD.Job'
			Set @S = @S +                     ' INNER JOIN T_Mass_Tags MT'
			Set @S = @S +                         ' ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID'
			Set @S = @S +                     ' INNER JOIN T_Score_Sequest SS'
			Set @S = @S +                         ' ON Pep.Peptide_ID = SS.Peptide_ID'
			Set @S = @S +                     ' INNER JOIN T_Score_Discriminant SD'
			Set @S = @S +                         ' ON Pep.Peptide_ID = SD.Peptide_ID'

			If @UseTerminusFilter > 0
			Begin
				Set @S = @S +                 ' LEFT OUTER JOIN #TerminusTable'				-- Use Left Outer Join since table will only be populated if one or more filters has ProteinTerminal >= 0
				Set @S = @S +                     ' ON MT.Mass_Tag_ID = #TerminusTable.Mass_Tag_ID'
			End
			Set @S = @S +                ' WHERE Pep.Charge_State ' + @ChargeStateComparison

			If NOT @ExperimentFilter IN ('', '%')
				Set @S = @S +                  ' AND TAD.Experiment LIKE ''' + @ExperimentFilter + ''''

			If NOT @ParamFileFilter IN ('', '%')
				Set @S = @S +                  ' AND TAD.Parameter_File_Name LIKE ''' + @ParamFileFilter + ''''

			Set @S = @S +                      ' AND SS.XCorr >= ' + Convert(varchar(12), @XCorr)
			Set @S = @S +                      ' AND SS.DeltaCN2 >= ' + Convert(varchar(12), @DeltaCN2)
			Set @S = @S +                      ' AND SD.Peptide_Prophet_Probability >= ' + Convert(varchar(12), @PeptideProphetProb)

			If @MSGFSpecProb < 1
				Set @S = @S +                  ' AND SD.MSGF_SpecProb <= ' + Convert(varchar(12), @MSGFSpecProb)
			
			If @CleavageStateComparison <> ''
				Set @S = @S +                  ' AND MT.Cleavage_State_Max ' + @CleavageStateComparison

			If @UseTerminusFilter > 0
				Set @S = @S +                  ' AND IsNull(#TerminusTable.Terminus_State, 0) ' + @TerminusStateComparison

			If @ModSymbolFilter <> ''
			Begin
				If @ModSymbolFilter = 'NoMods'
					Set @S = @S +              ' AND Not Pep.Peptide Like ''%[*#@!$%^&]%'''
				Else
					Set @S = @S +              ' AND Pep.Peptide Like ''%' + @ModSymbolFilter + '%'''
			End

			Set @S = @S +                ' ) LookupQ'
			Set @S = @S +         ' WHERE (ABS(DelM_PPM) <= ' + Convert(varchar(12), @DeltaMassPPM) + ' ) '
			Set @S = @S +     ' ) FilterQ ON NMTS.Mass_Tag_ID = FilterQ.Mass_Tag_ID'

			If @PreviewSql <> 0
				Print @S
			Else
				Exec (@S)
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
		Set @message = 'Updated the PMT_Quality_Score values in T_Mass_Tags using custom tolerances based on Experiment, Charge State, DeltaMass (ppm), XCorr, DeltaCN2, Cleavage State, etc.; Updated scores for ' + Convert(varchar(12), @myRowCount) + ' AMTs'
		
		execute PostLogEntry 'Normal', @message, 'UpdatePMTQSUsingCustomFilters'

	End
		
	
Done:
	return @myError

GO
