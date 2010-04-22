-- UpdatePMTQSUsingCustomTaoFilters is in these DBs:
--   MT_Human_EIF_NAF_P328           on Elmer
--   MT_Human_Schutzer_CSF_P420      on Elmer
--   MT_Human_Schutzer_CSF_P512      on Elmer
--   MT_D_Melanogaster_NCI_P531      on Albert
--	 MT_Human_BreastCancer_WRI_P582  on Elmer
--
-- UpdatePMTQSUsingCustomVladFilters            is in DB MT_Mouse_Voxel_P477
-- UpdatePMTQSUsingCustomVladFiltersHumanALZ is in DB MT_Human_ALZ_P514


SET QUOTED_IDENTIFIER ON
SET ANSI_PADDING ON
GO

CREATE TABLE [dbo].[T_Custom_PMT_QS_Criteria](
	[Group_ID] [int] IDENTITY(1,1) NOT NULL,
	[Experiment_Filter_List] [varchar](750) NOT NULL,
	[Tryptic_State] [smallint] NOT NULL,
	[Charge_State_Comparison] [varchar](3) NOT NULL,
	[DeltaCN2] [float] NOT NULL,
	[Xcorr] [float] NOT NULL,
	[Delta_Mass_ppm_min] [float] NOT NULL,
	[Delta_Mass_ppm_max] [float] NOT NULL,
 CONSTRAINT [PK_T_Custom_PMT_QS_Criteria] PRIMARY KEY CLUSTERED ([Group_ID] ASC)
)

GO

SET ANSI_PADDING OFF

CREATE UNIQUE NONCLUSTERED INDEX [IX_T_Custom_PMT_QS_Criteria] ON [dbo].[T_Custom_PMT_QS_Criteria] 
(
	[Experiment_Filter_List] ASC,
	[Tryptic_State] ASC,
	[Charge_State_Comparison] ASC,
	[DeltaCN2] ASC
)

GO
ALTER PROCEDURE UpdatePMTQSUsingCustomTaoFilters
/****************************************************
** 
**	Desc:	Updates the PMT Quality Score values for the peptides originating
**			from the Experiments defined by the Experiment_Filter_List column in T_Custom_PMT_QS_Criteria
**
**			Note that Experiment_Filter_List can contain a comma-separated list of experiments to match.  If the
**			 experiment name does not contain a % sign, then it must be an exact match.  If the name does contain
**			 a % sign, then a LIKE test is used
**
**			If @PMTQSAddon is > 0, then adds that value to PMTs that pass the custom filters
**
**			If @PMTQSAddon = 0 but @UpdatePMTQSForFilterPassingPeptides = 1, then changes the
**			PMT QS value to 2 for peptides that pass the custom filters
**
**			Note that PMT Quality Score values will be left unchanged for AMTs found in datasets that 
**			do not match the experiments in T_Custom_PMT_QS_Criteria
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	10/15/2007
**			04/02/2008 mem - Renamed column Experiment_Prefix to Experiment_Filter
**						   - Added parameter @PMTQSNew
**			03/16/2009 mem - Renamed column Experiment_Filter to Experiment_Filter_List
**						   - Updated to allow for comma separated experiment match specs in the Experiment_Filter_List column
**						   - Updated to use the text-based Charge_State_Comparison column instead of the smallint Charge_State column
**			06/04/2009 mem - Updated to support assymetric Delta Mass tolerances using fields Delta_Mass_PPM_min and Delta_Mass_PPM_max in table T_Custom_PMT_QS_Criteria
**			01/25/2010 mem - Updated to not apply a mass filter if Delta_Mass_PPM_min and Delta_Mass_PPM_max are zero
**    
*****************************************************/
(
	@PMTQSAddon real = 0,									
	@UpdatePMTQSForFilterPassingPeptides tinyint = 1,		-- When 1, then sets the PMT QS to @PMTQSNew for peptides that pass the custom filters
	@PMTQSNew int = 2,										-- New PMT Quality score to assign when @UpdatePMTQSForFilterPassingPeptides is non-zero
	@InfoOnly tinyint = 0,
	@PreviewSql tinyint = 0,
	@ShowRuleStats tinyint = 0,
	@message varchar(255) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @S varchar(max)
	declare @ExperimentLikeClauseList varchar(max)
	
	Declare @continue int
	Declare @EntryID int
	Declare @GroupID int
	
	Declare @ExperimentFilterList varchar(750)
	Declare @ExperimentFilterListSaved varchar(750)
	
	Declare @CleavageState smallint
	Declare @ChargeStateComparison varchar(3)
	Declare @DeltaCN2 float
	Declare @PPMToleranceMin float
	Declare @PPMToleranceMax float
	
	Declare @XCorr float
	
	Declare @MTCountPassingFilter int
	Declare @FilterByDelM tinyint
	
	-------------------------------------------------------------
	-- Validate the inputs
	-------------------------------------------------------------
	
	Set @PMTQSAddon = IsNull(@PMTQSAddon, 0)
	Set @UpdatePMTQSForFilterPassingPeptides = IsNull(@UpdatePMTQSForFilterPassingPeptides, 1)
	Set @PMTQSNew = IsNull(@PMTQSNew, 2)

	Set @InfoOnly = IsNull(@InfoOnly, 0)
	Set @PreviewSql = IsNull(@PreviewSql, 0)
	Set @ShowRuleStats = IsNull(@ShowRuleStats, 0)
	
	Set @message = ''

	If @PreviewSql <> 0 AND @InfoOnly = 0
		Set @InfoOnly = 1
		
	If @PMTQSAddon = 0 AND @UpdatePMTQSForFilterPassingPeptides = 0
	Begin
		set @message = 'Warning, both @PMTQSAddon and @UpdatePMTQSForFilterPassingPeptides are 0, so no PMT Quality Score values will be updated'
		SELECT @message
		
		if @infoOnly = 0
			execute PostLogEntry 'Error', @message, 'UpdatePMTQSUsingCustomTaoFilters'

		set @message = ''
	End
	
	--------------------------------------------------------------
	-- Create a temporary table to hold the Mass_Tag_IDs that pass the filter
	--------------------------------------------------------------

	CREATE TABLE #TmpDatasetsToProcess (
		Dataset_ID int NOT NULL,
		Experiment varchar(256) NOT NULL,
		ProcessDataset tinyint NULL
	)
	
	CREATE TABLE #TmpRuleStats (
		Group_ID int NOT NULL,
		MT_Count_Passing_Filter int NOT NULL,
		MT_Count_Added int NOT NULL
	)
	
	-- The following table will hold the AMTs that pass the filters
	--   If @PMTQSAddon is <> 0, then these AMTs will get their PMT Quality Score value bumped up by @PMTQSAddon
	--   If @PMTQSAddon = 0, then AMTs in #TmpMTsPassingFilters will get their PMT Quality Score values changed to 2 (skipping those with Group_ID < 0)
	CREATE TABLE #TmpMTsPassingFilters (
		Mass_Tag_ID int,
		Group_ID int				-- Corresponds to Group_ID in T_Custom_PMT_QS_Criteria; -1 if the Dataset doesn't match the Experiments in T_Custom_PMT_QS_Criteria
	)

	CREATE TABLE #TmpAddnlMTs (
		Mass_Tag_ID int
	)
	
	CREATE TABLE #TmpExperimentFilters (
		EntryID int IDENTITY (1,1),
		Experiment_Filter_List varchar(750)
	)
	

	--------------------------------------------------------------
	-- Populate #TmpDatasetsToProcess
	--------------------------------------------------------------
	--
	INSERT INTO #TmpDatasetsToProcess (Dataset_ID, Experiment, ProcessDataset)
	SELECT Dataset_ID, Experiment, 0 AS ProcessDataset
	FROM T_Analysis_Description
	ORDER BY Dataset_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	--------------------------------------------------------------
	-- Populate #TmpExperimentFilters
	--------------------------------------------------------------
	--
	INSERT INTO #TmpExperimentFilters (Experiment_Filter_List)
	SELECT DISTINCT Experiment_Filter_List
	FROM T_Custom_PMT_QS_Criteria	

	--------------------------------------------------------------
	-- Process each entry in #TmpExperimentFilters
	--------------------------------------------------------------
	
	Set @EntryID = -1
	Set @continue = 1
	While @continue = 1
	Begin -- <a1>
	
		SELECT TOP 1 
			@EntryID = EntryID,
			@ExperimentFilterList = Experiment_Filter_List			
		FROM #TmpExperimentFilters
		WHERE EntryID > @EntryID
		ORDER BY EntryID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin -- <b1>
					
			-- Use the experiments in @ExperimentFilterList to mark the matching datasets in #TmpDatasetsToProcess
			Set @ExperimentLikeClauseList = NULL
			SELECT @ExperimentLikeClauseList = Coalesce(@ExperimentLikeClauseList + ' OR ', '') + 
									'Experiment LIKE ''' + 
									CASE WHEN CharIndex('%', Value) < 1 
									THEN '%' + Value + '%'
									ELSE Value
									END + ''''
			FROM dbo.udfParseDelimitedList (@ExperimentFilterList, ',' )
			ORDER BY Value
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			If @myRowCount = 0
			Begin
				Set @Message = 'Invalid experiment filter list encountered in T_Custom_PMT_QS_Criteria; unable to continue'
				Set @myError = 50000
				Goto Done
			End
			
			-- Update #TmpDatasetsToProcess.ProcessDataset	
			Set @S = ''
			Set @S = @S + ' UPDATE #TmpDatasetsToProcess'
			Set @S = @S + ' SET ProcessDataset = 1'
			Set @S = @S + ' WHERE ' + @ExperimentLikeClauseList
			
			If @PreviewSql <> 0
				Print @S
				
			Exec (@S)
						
			
		End -- </b1>
	End -- </a1>
	

	If @InfoOnly <> 0
		SELECT Experiment, Dataset_ID, ProcessDataset
		FROM #TmpDatasetsToProcess
		ORDER BY Experiment, Dataset_ID

	--------------------------------------------------------------
	-- Populate #TmpMTsPassingFilters with the MTs found only in the datasets with #TmpDatasetsToProcess.ProcessDataset = 0
	-- These MTs will be skipped in later processing
	--------------------------------------------------------------
	
	Set @S = ''
	Set @S = @S + ' INSERT INTO #TmpMTsPassingFilters (Mass_Tag_ID, Group_ID)'
	Set @S = @S + ' SELECT DISTINCT MT.Mass_Tag_ID, -1 AS Group_ID'
	Set @S = @S + ' FROM T_Mass_Tags MT INNER JOIN '
	Set @S = @S +      ' T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID INNER JOIN '
	Set @S = @S +      ' T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job INNER JOIN '
	Set @S = @S +      ' #TmpDatasetsToProcess TmpDS ON TAD.Dataset_ID = TmpDS.Dataset_ID'
	Set @S = @S + ' WHERE (TmpDS.ProcessDataset = 0) AND '
	Set @S = @S + '       NOT MT.Mass_Tag_ID IN ('
	Set @S = @S +        ' SELECT DISTINCT MT.Mass_Tag_ID'
	Set @S = @S +        ' FROM T_Mass_Tags MT INNER JOIN '
	Set @S = @S +             ' T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID INNER JOIN '
	Set @S = @S +             ' T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job INNER JOIN '
	Set @S = @S +             ' #TmpDatasetsToProcess TmpDS ON TAD.Dataset_ID = TmpDS.Dataset_ID'
	Set @S = @S +         ' WHERE (TmpDS.ProcessDataset > 0)'	
	Set @S = @S +         ' )'
	
	If @PreviewSql <> 0
		Print @S
	Else
		Exec (@S)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @PreviewSql = 0
		INSERT INTO #TmpRuleStats (Group_ID, MT_Count_Passing_Filter, MT_Count_Added)
		VALUES (-1, 0, @myRowCount)

	--------------------------------------------------------------
	-- Now step through the criteria in T_Custom_PMT_QS_Criteria
	-- For each, test the data for the Datasets with #TmpDatasetsToProcess.ProcessDataset = 1,
	--  appending to #TmpMTsPassingFilters any new peptides that pass the filters
	--------------------------------------------------------------
	
	Set @ExperimentFilterListSaved = ''
	
	Set @GroupID = -1
	Set @continue = 1
	While @continue <> 0
	Begin -- <a2>
		SELECT TOP 1 
				@GroupID = Group_ID, 
				@ExperimentFilterList = Experiment_Filter_List, 
				@CleavageState = Tryptic_State,
				@ChargeStateComparison = LTrim(RTrim(Charge_State_Comparison)), 
				@DeltaCN2 = DeltaCN2, 
				@PPMToleranceMin = Delta_Mass_ppm_min,
				@PPMToleranceMax = Delta_Mass_ppm_max,
				@XCorr = Xcorr
		FROM T_Custom_PMT_QS_Criteria
		WHERE Group_ID > @GroupID
		ORDER BY Group_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin -- <b2>

			If @ChargeStateComparison Like '[0-9]'
			Begin
				-- @ChargeStateComparison only contains a number; prepend with an equals sign
				Set @ChargeStateComparison = '=' + @ChargeStateComparison
			End

			If IsNull(@ExperimentFilterListSaved, '') <> @ExperimentFilterList
			Begin
				-- Saved experiment filter list is not the same as @ExperimentFilterList
				-- Use the experiments in @ExperimentFilterList to construct a series of Experiment Name LIKE clauses
				
				Set @ExperimentLikeClauseList = NULL
				SELECT @ExperimentLikeClauseList = Coalesce(@ExperimentLikeClauseList + ' OR ', '') + 
										'TmpDS.Experiment LIKE ''' + 
										CASE WHEN CharIndex('%', Value) < 1 
										THEN '%' + Value + '%'
										ELSE Value
										END + ''''
				FROM dbo.udfParseDelimitedList (@ExperimentFilterList, ',' )
				ORDER BY Value
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				Set @ExperimentFilterListSaved = @ExperimentFilterList
			End
								
			
			TRUNCATE TABLE #TmpAddnlMTs
			
			If @PPMToleranceMin = 0 And @PPMToleranceMax = 0
				Set @FilterByDelM = 0
			Else
				Set @FilterByDelM = 1
				
			Set @S = ''
			Set @S = @S + ' INSERT INTO #TmpAddnlMTs (Mass_Tag_ID)'	
			Set @S = @S + ' SELECT MassTagsQ.Mass_Tag_ID'

			Set @S = @S + ' FROM ( SELECT T_Peptides.Mass_Tag_ID'
			Set @S = @S +        ' FROM T_Peptides INNER JOIN'

			If @FilterByDelM = 0
			Begin
				Set @S = @S +           ' ( SELECT Peptide_ID'
				Set @S = @S +         ' FROM (SELECT Peptide_ID'
				Set @S = @S +                   ' FROM (SELECT P.Peptide_ID'
			End
			Else
			Begin			
				Set @S = @S +           ' ( SELECT Peptide_ID, DelM_PPM'
				Set @S = @S +         ' FROM (SELECT Peptide_ID, CorrectedDelM / (Monoisotopic_Mass / 1e6) AS DelM_PPM'
				Set @S = @S +                   ' FROM (SELECT P.Peptide_ID, MT.Monoisotopic_Mass,'
				Set @S = @S +                                ' CASE WHEN SS.DelM BETWEEN -3.1 AND -2.9 THEN DelM + 3 '
				Set @S = @S +                                ' WHEN SS.DelM BETWEEN -2.1 AND -1.9 THEN DelM + 2 '
				Set @S = @S +                                ' WHEN SS.DelM BETWEEN -1.1 AND -0.9 THEN DelM + 1' 
				Set @S = @S +                                ' WHEN SS.DelM BETWEEN 0.9 AND 1.1 THEN DelM - 1 '
				Set @S = @S +                                ' WHEN SS.DelM BETWEEN 1.9 AND 2.1 THEN DelM - 2 '
				Set @S = @S +                                ' WHEN SS.DelM BETWEEN 2.9 AND 3.1 THEN DelM - 3 '
				Set @S = @S +                                ' ELSE SS.DelM END AS CorrectedDelM'
			End
			
			Set @S = @S +                         ' FROM T_Peptides P INNER JOIN'
			Set @S = @S +                              ' T_Score_Sequest SS ON P.Peptide_ID = SS.Peptide_ID INNER JOIN'
			Set @S = @S +                              ' T_Mass_Tags MT ON P.Mass_Tag_ID = MT.Mass_Tag_ID INNER JOIN'
			Set @S = @S +                              ' T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job INNER JOIN '
			Set @S = @S +                              ' #TmpDatasetsToProcess TmpDS ON TAD.Dataset_ID = TmpDS.Dataset_ID'
			Set @S = @S +                         ' WHERE (' + @ExperimentLikeClauseList + ') AND'
			Set @S = @S +                               ' P.Charge_State ' + @ChargeStateComparison + ' AND'
			Set @S = @S +                               ' SS.DeltaCN2 >= ' + Convert(varchar(12), @DeltaCN2) + ' AND'
			Set @S = @S +                               ' SS.XCorr >= ' + Convert(varchar(12), @XCorr)
			Set @S = @S +                        ' ) LookupQ'
			Set @S = @S +                   ' ) OuterQ'
			
			If @FilterByDelM = 1
				Set @S = @S +         ' WHERE DelM_PPM BETWEEN ' + Convert(varchar(12), @PPMToleranceMin) + ' AND ' + Convert(varchar(12), @PPMToleranceMax)
				
			Set @S = @S +       ' ) LookupQ ON T_Peptides.Peptide_ID = LookupQ.Peptide_ID'
			Set @S = @S +       ' GROUP BY T_Peptides.Mass_Tag_ID) MassTagsQ INNER JOIN'
			Set @S = @S +       ' T_Mass_Tag_to_Protein_Map MTPM ON MassTagsQ.Mass_Tag_ID = MTPM.Mass_Tag_ID'
			Set @S = @S + ' WHERE IsNull(MTPM.Cleavage_State, 0) >= ' + Convert(varchar(4), @CleavageState)
			Set @S = @S + ' GROUP BY MassTagsQ.Mass_Tag_ID'
			
			If @PreviewSql <> 0
				Print @S
			Else
				Exec (@S)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @PreviewSql = 0
				Set @MTCountPassingFilter = @myRowCount
				
			Set @S = ''
			Set @S = @S + ' INSERT INTO #TmpMTsPassingFilters (Mass_Tag_ID, Group_ID)'
			Set @S = @S + ' SELECT #TmpAddnlMTs.Mass_Tag_ID, ' + Convert(varchar(12), @GroupID) + ' AS Group_ID'
			Set @S = @S + ' FROM #TmpAddnlMTs LEFT OUTER JOIN'
			Set @S = @S +      ' #TmpMTsPassingFilters ON #TmpAddnlMTs.Mass_Tag_ID = #TmpMTsPassingFilters.Mass_Tag_ID'
			Set @S = @S + ' WHERE #TmpMTsPassingFilters.Mass_Tag_ID IS NULL'
	
			If @PreviewSql <> 0
				Print @S
			Else
				Exec (@S)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @PreviewSql = 0
				INSERT INTO #TmpRuleStats (Group_ID, MT_Count_Passing_Filter, MT_Count_Added)
				VALUES (@GroupID, @MTCountPassingFilter, @myRowCount)

		End -- </b2>
	End -- </a2>

	
	If @PreviewSql = 0
	Begin
		Set @message = ''
		
		SELECT @myRowCount = COUNT(*)
		FROM #TmpMTsPassingFilters
		WHERE Group_ID < 0
		
		Set @message = @message + 'PMTs skipped since not matched by the Experiment filter: ' + Convert(varchar(12), @myRowCount)

		SELECT @myRowCount = COUNT(*)
		FROM #TmpMTsPassingFilters
		WHERE Group_ID >= 0
		
		Set @message = @message + '; PMTs passing the custom filters: ' + Convert(varchar(12), @myRowCount)

	End
			
	If @InfoOnly <> 0 And @PreviewSql = 0
	Begin
		SELECT @message as Message
	End
	Else
	Begin
		-- Either @InfoOnly = 0 OR @PreviewSql = 1
		
		If @PMTQSAddon <> 0
		Begin
			Set @S = ''
			Set @S = @S + ' UPDATE T_Mass_Tags'
			Set @S = @S + ' SET PMT_Quality_Score = PMT_Quality_Score ' +  Convert(varchar(12), @PMTQSAddon)
			Set @S = @S + ' FROM T_Mass_Tags MT INNER JOIN '
			Set @S = @S +      ' #TmpMTsPassingFilters MTU ON MT.Mass_Tag_ID = MTU.Mass_Tag_ID'
			Set @S = @S + ' WHERE MTU.Group_ID >= 0'
				
			If @PreviewSql <> 0
				Print @S
			Else
				Exec (@S)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
		
			Set @message = @message + '; increased their PMT QS values by ' + convert(varchar(12), @PMTQSAddon)
		End
		
		If @UpdatePMTQSForFilterPassingPeptides <> 0
		Begin
			Set @S = ''
			Set @S = @S + ' UPDATE T_Mass_Tags'
			Set @S = @S + ' SET PMT_Quality_Score = ' + Convert(varchar(12), @PMTQSNew)
			Set @S = @S + ' FROM T_Mass_Tags MT INNER JOIN #TmpMTsPassingFilters MTU ON '
			Set @S = @S +      ' MT.Mass_Tag_ID = MTU.Mass_Tag_ID'
			Set @S = @S + ' WHERE MTU.Group_ID >= 0 AND MT.PMT_Quality_Score <> ' + Convert(varchar(12), @PMTQSNew)
				
			If @PreviewSql <> 0
				Print @S
			Else
				Exec (@S)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			Set @message = @message + '; set PMT QS to 2 for PMTs that pass the custom filters (' + convert(varchar(12), @myRowCount) + ' PMTs updated)'
		End
		
		If @InfoOnly = 0 AND @PreviewSql = 0 
		Begin
			execute PostLogEntry 'Normal', @message, 'UpdatePMTQSUsingCustomTaoFilters'
		End
	End

	If @InfoOnly <> 0 OR @ShowRuleStats <> 0
	Begin
		SELECT *
		FROM #TmpRuleStats
		ORDER BY Group_ID
	End
	
Done:
	If @myError <> 0
		SELECT @Message as ErrorMessage
		
	return @myError

GO
