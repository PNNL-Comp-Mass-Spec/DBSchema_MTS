/****** Object:  StoredProcedure [dbo].[UpdatePMTQSUsingCustomTaoFilters] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.UpdatePMTQSUsingCustomTaoFilters
/****************************************************
** 
**	Desc:	Updates the PMT Quality Score values for the peptides originating
**			from the Experiments defined by the Experiment_Prefix column in T_Custom_PMT_QS_Criteria
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
**    
*****************************************************/
(
	@PMTQSAddon real = 0,
	@UpdatePMTQSForFilterPassingPeptides tinyint = 1,		-- When 1, then sets the PMT QS to 2 for peptides that pass the custom filters
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

	declare @S varchar(max)
	declare @LikeClauseList varchar(2048)
	
	Declare @continue int
	Declare @GroupID int
	Declare @ExperimentPrefix varchar(128)
	Declare @CleavageState smallint
	Declare @ChargeState smallint
	Declare @DeltaCN2 float
	Declare @PPMTolerance float
	Declare @XCorr float
	
	Declare @MTCountPassingFilter int
	
	-------------------------------------------------------------
	-- Validate the inputs
	-------------------------------------------------------------
	
	Set @PMTQSAddon = IsNull(@PMTQSAddon, 0)
	Set @UpdatePMTQSForFilterPassingPeptides = IsNull(@UpdatePMTQSForFilterPassingPeptides, 0)
	Set @InfoOnly = IsNull(@InfoOnly, 0)
	Set @PreviewSql = IsNull(@PreviewSql, 0)
	Set @message = ''

	If @PreviewSql <> 0 AND @InfoOnly = 0
		Set @InfoOnly = 1
		
	If @PMTQSAddon = 0 AND @UpdatePMTQSForFilterPassingPeptides = 0
	Begin
		set @message = 'Warning, both @PMTQSAddon and @UpdatePMTQSForFilterPassingPeptides are 0, so no PMT Quality Score values will be updated'
		SELECT @message
		
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
	--   If @PMTQSAddon = 0, then AMTs in #TmpMTsPassingFilters will get their PMT Quality Score values changed to 2 (skipping those with Group_ID = 0)
	CREATE TABLE #TmpMTsPassingFilters (
		Mass_Tag_ID int,
		Group_ID int				-- Corresponds to Group_ID in T_Custom_PMT_QS_Criteria; 0 if the Dataset doesn't match the Experiments in T_Custom_PMT_QS_Criteria
	)

	CREATE TABLE #TmpAddnlMTs (
		Mass_Tag_ID int
	)
	
	-- Populate #TmpDatasetsToProcess
	INSERT INTO #TmpDatasetsToProcess (Dataset_ID, Experiment, ProcessDataset)
	SELECT Dataset_ID, Experiment, 0 AS ProcessDataset
	FROM T_Analysis_Description
	ORDER BY Dataset_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	-- Use #TmpExperimentPrefixes to mark the matching datasets in #TmpDatasetsToProcess
	Set @LikeClauseList = ''
	SELECT @LikeClauseList = @LikeClauseList + 'Experiment LIKE ''' + Experiment_Prefix + '%'' OR '
	FROM T_Custom_PMT_QS_Criteria
	GROUP BY Experiment_Prefix
	ORDER BY Experiment_Prefix
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myRowCount = 0
	Begin
		Set @Message = 'Table T_Custom_PMT_QS_Criteria is empty; unable to continue'
		Set @myError = 50000
		Goto Done
	End
	
	-- Remove the trailing ' OR ' from @LikeClauseList
	Set @LikeClauseList = RTrim(@LikeClauseList)
	Set @LikeClauseList = Substring(@LikeClauseList, 1, Len(@LikeClauseList)- 3)
	
	-- Update #TmpDatasetsToProcess.ProcessDataset	
	Set @S = ''
	Set @S = @S + ' UPDATE #TmpDatasetsToProcess'
	Set @S = @S + ' SET ProcessDataset = 1'
	Set @S = @S + ' WHERE ' + @LikeClauseList
	
	Exec (@S)
	
	-- Populate #TmpMTsPassingFilters with the MTs found in the datasets with #TmpDatasetsToProcess.ProcessDataset = 0
	-- These MTs will be skipped from any further processing
	
	Set @S = ''
	Set @S = @S + ' INSERT INTO #TmpMTsPassingFilters (Mass_Tag_ID, Group_ID)'
	Set @S = @S + ' SELECT DISTINCT MT.Mass_Tag_ID, 0 AS Group_ID'
	Set @S = @S + ' FROM T_Mass_Tags MT INNER JOIN '
	Set @S = @S +      ' T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID INNER JOIN '
	Set @S = @S +      ' T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job INNER JOIN '
	Set @S = @S +      ' #TmpDatasetsToProcess TmpDS ON TAD.Dataset_ID = TmpDS.Dataset_ID'
	Set @S = @S + ' WHERE (MT.PMT_Quality_Score > 0) AND (TmpDS.ProcessDataset = 0)'
	
	If @PreviewSql <> 0
		Print @S
	Else
		Exec (@S)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @PreviewSql = 0
		INSERT INTO #TmpRuleStats (Group_ID, MT_Count_Passing_Filter, MT_Count_Added)
		VALUES (0, 0, @myRowCount)

	-- Now step through the criteria in T_Custom_PMT_QS_Criteria
	-- For each, test the data for the Datasets with #TmpDatasetsToProcess.ProcessDataset = 1,
	--  appending to #TmpMTsPassingFilters any new peptides that pass the filters

	Set @GroupID = 0
	Set @continue = 1
	While @continue <> 0
	Begin -- <a>
		SELECT TOP 1 
				@GroupID = Group_ID, 
				@ExperimentPrefix = Experiment_Prefix, 
				@CleavageState = Tryptic_State,
				@ChargeState = Charge_State, 
				@DeltaCN2 = DeltaCN2, 
				@PPMTolerance = Delta_Mass_ppm, 
				@XCorr = Xcorr
		FROM T_Custom_PMT_QS_Criteria
		WHERE Group_ID > @GroupID
		ORDER BY Group_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin -- <b>

			TRUNCATE TABLE #TmpAddnlMTs
			
			Set @S = ''
			Set @S = @S + ' INSERT INTO #TmpAddnlMTs (Mass_Tag_ID)'	
			Set @S = @S + ' SELECT MassTagsQ.Mass_Tag_ID'
			Set @S = @S + ' FROM ( SELECT T_Peptides.Mass_Tag_ID'
			Set @S = @S +        ' FROM T_Peptides INNER JOIN'
			Set @S = @S +           ' ( SELECT Peptide_ID, DelM_PPM'
			Set @S = @S +             ' FROM (SELECT Peptide_ID, CorrectedDelM / (Monoisotopic_Mass / 1e6) AS DelM_PPM'
			Set @S = @S +                   ' FROM (SELECT P.Peptide_ID, MT.Monoisotopic_Mass,'
			Set @S = @S +                                ' CASE WHEN SS.DelM BETWEEN -3.1 AND -2.9 THEN DelM + 3 '
			Set @S = @S +                                ' WHEN SS.DelM BETWEEN -2.1 AND -1.9 THEN DelM + 2 '
			Set @S = @S +                                ' WHEN SS.DelM BETWEEN -1.1 AND -0.9 THEN DelM + 1' 
			Set @S = @S +                                ' WHEN SS.DelM BETWEEN 0.9 AND 1.1 THEN DelM - 1 '
			Set @S = @S +                                ' WHEN SS.DelM BETWEEN 1.9 AND 2.1 THEN DelM - 2 '
			Set @S = @S +                                ' WHEN SS.DelM BETWEEN 2.9 AND 3.1 THEN DelM - 3 '
			Set @S = @S +                                ' ELSE SS.DelM END AS CorrectedDelM'
			Set @S = @S +                         ' FROM T_Peptides P INNER JOIN'
			Set @S = @S +                              ' T_Score_Sequest SS ON P.Peptide_ID = SS.Peptide_ID INNER JOIN'
			Set @S = @S +                              ' T_Mass_Tags MT ON P.Mass_Tag_ID = MT.Mass_Tag_ID INNER JOIN'
			Set @S = @S +                              ' T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job INNER JOIN '
			Set @S = @S +       ' #TmpDatasetsToProcess TmpDS ON TAD.Dataset_ID = TmpDS.Dataset_ID'
			Set @S = @S +                         ' WHERE TmpDS.Experiment LIKE ''' + @ExperimentPrefix + '%'' AND'
			Set @S = @S +                               ' P.Charge_State = ' + Convert(varchar(4), @ChargeState) + ' AND'
			Set @S = @S +                               ' SS.DeltaCN2 >= ' + Convert(varchar(12), @DeltaCN2) + ' AND'
			Set @S = @S +                               ' SS.XCorr >= ' + Convert(varchar(12), @XCorr)
			Set @S = @S +                        ' ) LookupQ'
			Set @S = @S +                   ' ) OuterQ'
			Set @S = @S +             ' WHERE DelM_PPM BETWEEN ' + Convert(varchar(12), -@PPMTolerance) + ' AND ' + Convert(varchar(12), @PPMTolerance)
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

		End -- </b>
	End -- </a>

	
	If @PreviewSql = 0
	Begin
		Set @message = ''
		
		SELECT @myRowCount = COUNT(*)
		FROM #TmpMTsPassingFilters
		WHERE Group_ID = 0
		
		Set @message = @message + 'PMTs skipped since not matched by the Experiment_Prefix filter: ' + Convert(varchar(12), @myRowCount)

		SELECT @myRowCount = COUNT(*)
		FROM #TmpMTsPassingFilters
		WHERE Group_ID <> 0
		
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
			Set @S = @S + ' WHERE MTU.Group_ID > 0'
				
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
			Set @S = @S + ' SET PMT_Quality_Score = 2'
			Set @S = @S + ' FROM T_Mass_Tags MT INNER JOIN #TmpMTsPassingFilters MTU ON '
			Set @S = @S +      ' MT.Mass_Tag_ID = MTU.Mass_Tag_ID'
			Set @S = @S + ' WHERE MTU.Group_ID > 0 AND MT.PMT_Quality_Score <> 2'
				
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

	If @InfoOnly <> 0
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
