SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ComputeMassTagsAnalysisCounts]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ComputeMassTagsAnalysisCounts]
GO


CREATE PROCEDURE dbo.ComputeMassTagsAnalysisCounts
/****************************************************
**
**	Desc: 
**		Recomputes the values for Number_Of_Peptides,
**		 High_Normalized_Score, and High_Discriminant_Score in T_Mass_Tags
**		Only counts peptides from the same dataset once,
**		 even if the dataset has several analysis jobs
**		Does count a peptide multiple times if it was seen
**		 in different scans in the same analysis for the same dataset
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 09/19/2004
**			  05/20/2005 mem - Now verifying the value of Internal_Standard_Only
**			  09/28/2005 mem - Now updating column Peptide_Obs_Count_Passing_Filter
**    
*****************************************************/
	@message varchar(255)='' OUTPUT,
	@UpdateFilteredObsStatsOnly tinyint = 0
AS

	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Set @message= ''

	If @UpdateFilteredObsStatsOnly = 0
	Begin
		
		-----------------------------------------------------------
		-- Update the general stats by examining T_Peptides and associated tables
		-----------------------------------------------------------
		--
		UPDATE T_Mass_Tags
		SET Number_Of_Peptides = IsNull(StatsQ.ObservationCount, 0),
			High_Normalized_Score = IsNull(StatsQ.MaxXCorr, 0),
			High_Discriminant_Score = IsNull(Statsq.MaxDiscriminantScore, 0)
		FROM T_Mass_Tags LEFT OUTER JOIN
			(
				SELECT	Mass_Tag_ID, 
						COUNT(*) AS ObservationCount, 
						MAX(MaxXCorr) AS MaxXCorr,
						MAX(MaxDiscriminantScore) AS MaxDiscriminantScore
				FROM (	SELECT	P.Mass_Tag_ID, 
								P.Scan_Number, 
								MAX(ISNULL(SS.XCorr, 0)) AS MaxXCorr,
								MAX(ISNULL(SD.DiscriminantScoreNorm, 0)) AS MaxDiscriminantScore
						FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Analysis_ID = TAD.Job 
							LEFT OUTER JOIN T_Score_Sequest AS SS ON P.Peptide_ID = SS.Peptide_ID
							LEFT OUTER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID
						GROUP BY TAD.Dataset_ID,
								P.Mass_Tag_ID,
								P.Scan_Number
						) AS SubQ
				GROUP BY SubQ.Mass_Tag_ID			
			) AS StatsQ ON T_Mass_Tags.Mass_Tag_ID = StatsQ.Mass_Tag_ID	
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0
			Set @message = 'Error updating Number_Of_Peptides and High_Normalized_Score in T_Mass_Tags'

		
		-----------------------------------------------------------
		--  Verify that Internal_Standard_Only = 0 for all peptides with an entry in T_Peptides
		-----------------------------------------------------------
		--
		UPDATE T_Mass_Tags
		SET Internal_Standard_Only = 0
		FROM T_Mass_Tags INNER JOIN T_Peptides ON 
			T_Mass_Tags.Mass_Tag_ID = T_Peptides.Mass_Tag_ID
		WHERE Internal_Standard_Only = 1
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
	End


	-----------------------------------------------------------
	-- Update the stats for column Peptide_Obs_Count_Passing_Filter
	-----------------------------------------------------------
	--

	Declare @Sql varchar(4000)
	Declare @ConfigValue varchar(128)
	Declare @FilterSetID int
	
	-- Create a temporary table to track which PMTs pass the filter critera
	-- and the datasets and scan numbers the peptide was observed in

	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#TmpMTObsStats]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#TmpMTObsStats]

	CREATE TABLE #TmpMTObsStats (
		[Mass_Tag_ID] int NOT NULL,
		[Dataset_ID] int NOT NULL,
		[Scan_Number] int NOT NULL
	) ON [PRIMARY]

	CREATE CLUSTERED INDEX [#IX_TmpMTObsStats] ON [dbo].[#TmpMTObsStats]([Mass_Tag_ID]) ON [PRIMARY]

	-- Define the default Filter_Set_ID
	Set @FilterSetID = 141

	-- Lookup the Peptide_Obs_Count Filter_Set_ID value
	SELECT TOP 1 @ConfigValue = Value
	FROM T_Process_Config
	WHERE [Name] = 'Peptide_Obs_Count_Filter_ID'
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	If @myRowCount = 0
	 Begin
		-- Use the default FilterSetID value; post a warning to the log
		set @message = 'Warning: Entry Peptide_Obs_Count_Filter_ID not found in T_Process_Config; using default value of ' + Convert(varchar(9), @FilterSetID)
		execute PostLogEntry 'Error', @message, 'ComputeMassTagsAnalysisCounts'
	 End
	Else
	 Begin
		If IsNumeric(IsNull(@ConfigValue, '')) = 1
			Set @FilterSetID = Convert(int, @ConfigValue)
		Else
		Begin
			-- Use the default FilterSetID value; post a warning to the log
			set @message = 'An invalid entry for Peptide_Obs_Count_Filter_ID was found in T_Process_Config: ' + IsNull(@ConfigValue, 'NULL') + '; using default value of ' + Convert(varchar(9), @FilterSetID)
			execute PostLogEntry 'Error', @message, 'ComputeMassTagsAnalysisCounts'
		End
	 End

	-- Define the filter threshold values
	Declare @CriteriaGroupStart int,
			@CriteriaGroupMatch int,
			@SpectrumCountComparison varchar(2),			-- Not used in this SP
			@SpectrumCountThreshold int,					-- Not used in this SP
			@ChargeStateComparison varchar(2),
			@ChargeStateThreshold tinyint,
			@HighNormalizedScoreComparison varchar(2),
			@HighNormalizedScoreThreshold float,
			@CleavageStateComparison varchar(2),
			@CleavageStateThreshold tinyint,
			@PeptideLengthComparison varchar(2),
			@PeptideLengthThreshold smallint,
			@MassComparison varchar(2),
			@MassThreshold float,
			@DeltaCnComparison varchar(2),
			@DeltaCnThreshold float,
			@DeltaCn2Comparison varchar(2),
			@DeltaCn2Threshold float,
			@DiscriminantScoreComparison varchar(2),
			@DiscriminantScoreThreshold float,
			@NETDifferenceAbsoluteComparison varchar(2),
			@NETDifferenceAbsoluteThreshold float,
			@DiscriminantInitialFilterComparison varchar(2),		-- Not used in this SP
			@DiscriminantInitialFilterThreshold float,				-- Not used in this SP
			@ProteinCountComparison varchar(2),
			@ProteinCountThreshold int,
			@TerminusStateComparison varchar(2),
			@TerminusStateThreshold tinyint

	-- Validate that @FilterSetID is defined in V_Filter_Sets_Import
	-- Do this by calling GetThresholdsForFilterSet and examining @FilterGroupMatch
	Set @CriteriaGroupStart = 0
	Set @CriteriaGroupMatch = 0
	Exec @myError = GetThresholdsForFilterSet @FilterSetID, @CriteriaGroupStart, @CriteriaGroupMatch OUTPUT, @message OUTPUT
	
	If @myError <> 0
	Begin
		If Len(@message) = 0
			set @message = 'Could not validate filter set ID ' + Convert(varchar(11), @FilterSetID) + ' using GetThresholdsForFilterSet'		
		goto Done
	End
	
	If @CriteriaGroupMatch = 0 
	  Begin

		-- Invalid filter defined; post message to log
		set @message = 'Filter set ID ' + Convert(varchar(11), @FilterSetID) + ' not found using GetThresholdsForFilterSet'
		SELECT @message
		execute PostLogEntry 'Error', @message, 'ComputeMassTagsAnalysisCounts'
		Set @message = ''
	  End
	Else
	  Begin -- <a>
		

		-- Now call GetThresholdsForFilterSet to get the tresholds to filter against
		-- Set Passes_Filter to 1 in #TmpMTObsStats for the matching mass tags
		Set @CriteriaGroupStart = 0
		Set @CriteriaGroupMatch = 0
		Exec @myError = GetThresholdsForFilterSet @FilterSetID, @CriteriaGroupStart, @CriteriaGroupMatch OUTPUT, @message OUTPUT, 
										@SpectrumCountComparison OUTPUT,@SpectrumCountThreshold OUTPUT,
										@ChargeStateComparison OUTPUT,@ChargeStateThreshold OUTPUT,
										@HighNormalizedScoreComparison OUTPUT,@HighNormalizedScoreThreshold OUTPUT,
										@CleavageStateComparison OUTPUT,@CleavageStateThreshold OUTPUT,
										@PeptideLengthComparison OUTPUT,@PeptideLengthThreshold OUTPUT,
										@MassComparison OUTPUT,@MassThreshold OUTPUT,
										@DeltaCnComparison OUTPUT,@DeltaCnThreshold OUTPUT,
										@DeltaCn2Comparison OUTPUT,@DeltaCn2Threshold OUTPUT,
										@DiscriminantScoreComparison OUTPUT, @DiscriminantScoreThreshold OUTPUT,
										@NETDifferenceAbsoluteComparison OUTPUT, @NETDifferenceAbsoluteThreshold OUTPUT,
										@DiscriminantInitialFilterComparison OUTPUT, @DiscriminantInitialFilterThreshold OUTPUT,
										@ProteinCountComparison OUTPUT, @ProteinCountThreshold OUTPUT,
										@TerminusStateComparison OUTPUT, @TerminusStateThreshold OUTPUT

		While @CriteriaGroupMatch > 0
		Begin -- <b>

			-- Populate #TmpMTObsStats with the PMT tags passing the current criteria
			Set @Sql = ''
			Set @Sql = @Sql + ' INSERT INTO #TmpMTObsStats (Mass_Tag_ID, Dataset_ID, Scan_Number)'
			Set @Sql = @Sql + ' SELECT MT.Mass_Tag_ID, Dataset_ID, Scan_Number'
			Set @Sql = @Sql + ' FROM ('
			Set @Sql = @Sql +   ' SELECT Dataset_ID, Mass_Tag_ID, Scan_Number, GANET_Obs, Charge_State,'
			Set @Sql = @Sql +     ' MAX(SubQ.MaxXCorr) AS MaxXCorr,'
			Set @Sql = @Sql +     ' MAX(SubQ.MaxDiscriminantScore) AS MaxDiscriminantScore'
			Set @Sql = @Sql +   ' FROM ('
			Set @Sql = @Sql +      ' SELECT TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, P.GANET_Obs,'
			Set @Sql = @Sql +             ' P.Charge_State,'
			Set @Sql = @Sql +             ' MAX(IsNull(SS.XCorr, 0)) AS MaxXCorr,'
			Set @Sql = @Sql +             ' MAX(IsNull(SD.DiscriminantScoreNorm, 0)) As MaxDiscriminantScore'
			Set @Sql = @Sql +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Analysis_ID = TAD.Job'
			Set @Sql = @Sql +           ' LEFT OUTER JOIN T_Score_Sequest AS SS ON P.Peptide_ID = SS.Peptide_ID'
			Set @Sql = @Sql +           ' LEFT OUTER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
			Set @Sql = @Sql +      ' WHERE NOT P.Charge_State IS NULL AND'
			Set @Sql = @sql +            ' SS.DeltaCn ' + @DeltaCnComparison + Convert(varchar(11), @DeltaCnThreshold) + ' AND '
			Set @Sql = @sql +            ' SS.DeltaCn2 ' + @DeltaCn2Comparison + Convert(varchar(11), @DeltaCn2Threshold)
			Set @Sql = @sql +      ' GROUP BY TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, P.GANET_Obs, P.Charge_State'
			Set @Sql = @sql +      ') AS SubQ'
			Set @Sql = @sql +   ' GROUP BY Dataset_ID, Mass_Tag_ID, Scan_Number, GANET_Obs, Charge_State'
			Set @Sql = @sql +   ') AS StatsQ'
  			Set @Sql = @sql +   ' INNER JOIN T_Mass_Tags AS MT ON StatsQ.Mass_Tag_ID = MT.Mass_Tag_ID'
			Set @Sql = @sql +   ' LEFT OUTER JOIN T_Mass_Tag_to_Protein_Map AS MTPM ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID'
			Set @Sql = @sql +   ' LEFT OUTER JOIN T_Mass_Tags_NET AS MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID'
			Set @Sql = @Sql + ' WHERE '
			Set @Sql = @Sql +   ' StatsQ.Charge_State ' +  @ChargeStateComparison + Convert(varchar(11), @ChargeStateThreshold) + ' AND '
			Set @Sql = @Sql +   ' MaxXCorr ' +  @HighNormalizedScoreComparison + Convert(varchar(11), @HighNormalizedScoreThreshold) + ' AND '
			Set @Sql = @Sql +   ' ISNULL(MTPM.Cleavage_State, 0) ' + @CleavageStateComparison + Convert(varchar(11), @CleavageStateThreshold) + ' AND '
			Set @Sql = @Sql +   ' ISNULL(MTPM.Terminus_State, 0) ' + @TerminusStateComparison + Convert(varchar(11), @TerminusStateThreshold) + ' AND '
			Set @Sql = @Sql +   ' LEN(MT.Peptide) ' + @PeptideLengthComparison + Convert(varchar(11), @PeptideLengthThreshold) + ' AND '
			Set @Sql = @Sql +   ' IsNull(MT.Monoisotopic_Mass, 0) ' + @MassComparison + Convert(varchar(11), @MassThreshold) + ' AND '
			Set @Sql = @sql +   ' StatsQ.MaxDiscriminantScore ' + @DiscriminantScoreComparison + Convert(varchar(11), @DiscriminantScoreThreshold) + ' AND '
			Set @Sql = @sql +   ' IsNull(ABS(StatsQ.GANET_Obs - MTN.PNET), 0) ' + @NETDifferenceAbsoluteComparison + Convert(varchar(11), @NETDifferenceAbsoluteThreshold) + ' AND '
			Set @Sql = @sql +   ' IsNull(MT.Multiple_Proteins, 0) + 1 ' + @ProteinCountComparison + Convert(varchar(11), @ProteinCountThreshold)
			Set @Sql = @Sql + ' GROUP BY MT.Mass_Tag_ID, Dataset_ID, Scan_Number'

			Exec (@Sql)
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			If @myError <> 0
			Begin
				Set @Message = 'Error evaluating filter set criterion'
				Goto Done
			End

			-- Lookup the next set of filters
			Set @CriteriaGroupStart = @CriteriaGroupMatch + 1
			Set @CriteriaGroupMatch = 0
			
			Exec @myError = GetThresholdsForFilterSet @FilterSetID, @CriteriaGroupStart, @CriteriaGroupMatch OUTPUT, @message OUTPUT, 
											@SpectrumCountComparison OUTPUT,@SpectrumCountThreshold OUTPUT,
											@ChargeStateComparison OUTPUT,@ChargeStateThreshold OUTPUT,
											@HighNormalizedScoreComparison OUTPUT,@HighNormalizedScoreThreshold OUTPUT,
											@CleavageStateComparison OUTPUT,@CleavageStateThreshold OUTPUT,
											@PeptideLengthComparison OUTPUT,@PeptideLengthThreshold OUTPUT,
											@MassComparison OUTPUT,@MassThreshold OUTPUT,
											@DeltaCnComparison OUTPUT,@DeltaCnThreshold OUTPUT,
											@DeltaCn2Comparison OUTPUT,@DeltaCn2Threshold OUTPUT,
											@DiscriminantScoreComparison OUTPUT, @DiscriminantScoreThreshold OUTPUT,
											@NETDifferenceAbsoluteComparison OUTPUT, @NETDifferenceAbsoluteThreshold OUTPUT,
											@DiscriminantInitialFilterComparison OUTPUT, @DiscriminantInitialFilterThreshold OUTPUT,
											@ProteinCountComparison OUTPUT, @ProteinCountThreshold OUTPUT,
											@TerminusStateComparison OUTPUT, @TerminusStateThreshold OUTPUT

			If @myError <> 0
			Begin
				Set @Message = 'Error retrieving next entry from GetThresholdsForFilterSet in CheckFilterForAvailableAnalyses'
				Goto Done
			End


		End -- </b>
	
		-- Update T_Mass_Tags with the observation counts
		UPDATE T_Mass_Tags
		SET Peptide_Obs_Count_Passing_Filter = IsNull(StatsQ.Obs_Count, 0)
		FROM T_Mass_Tags LEFT OUTER JOIN
			(	SELECT Mass_Tag_ID, Count(*) AS Obs_Count
				FROM (	SELECT DISTINCT Mass_Tag_ID, Dataset_ID, Scan_Number
						FROM #TmpMTObsStats
					 ) InnerQ
				GROUP By Mass_Tag_ID
			) AS StatsQ ON T_Mass_Tags.Mass_Tag_ID = StatsQ.Mass_Tag_ID	
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

	  End -- </a>

	
Done:
	Return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

