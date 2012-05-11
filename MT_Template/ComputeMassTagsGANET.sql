/****** Object:  StoredProcedure [dbo].[ComputeMassTagsGANET] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure ComputeMassTagsGANET
/********************************************************
**	Synchronizes tables T_Mass_Tags_NET and T_Mass_Tags
**
**	Updates NET statistics in T_Mass_Tags_NET utilizing GANET_Obs value from T_Peptides
**
**	Date:	06/27/2003 mem
**			07/01/2003 mem
**			01/07/2004 mem - Lowered default MinGANETFit from 0.9 to 0.8
**						   - Increased random sampling size from 10000 to 500000
**			09/22/2004 mem - Updated to weight average GANET values on discriminant score values
**			11/27/2004 mem - Added use of GANET_RSquared
**			01/22/2005 mem - Added support for the ScanTime_NET columns
**			04/14/2005 mem - Now only counting peptides from the same dataset once, even if
**							  the dataset has several analysis jobs
**			04/18/2005 mem - Now excluding data from jobs with Slope values <= 0; also, assuring that NULL NET values are excluded from calculations
**			05/20/2005 mem - Updated logic to only use entries from T_Mass_Tags with Internal_Standard_Only = 0
**			07/06/2005 mem - Switched to storing the unbiased standard deviation in StD_GANET rather than the biased Standard Error
**			07/19/2005 mem - Switched back to storing the biased standard deviation in StD_GANET, but now making sure that we store 0 when NET_Cnt = 1
**			08/22/2005 mem - Updated formula for weighted standard error
**			10/09/2005 mem - Updated to only consider peptide entries with Max_Obs_Area_In_Job = 1 when computing the average NET value
**						   - Updated to use the GANET_Obs value in T_Peptides rather than recomputing the NET value using the Slope and Intercept defined in T_Analysis_Description; however, we're still filtering out peptides from jobs with Fit values below the given thresholds
**			12/01/2005 mem - Now considering option 'GANET_Avg_Use_Max_Obs_Area_In_Job_Enabled' in T_Process_Config
**			01/18/2006 mem - Now posting a message to T_Log_Entries on Success
**			03/13/2006 mem - Now calling UpdateCachedHistograms
**			09/07/2007 mem - Now posting log entries if the stored procedure runs for more than 2 minutes
**			11/12/2007 mem - Added parameter @infoOnly
**			01/06/2012 mem - Updated to use T_Peptides.Job
**
*********************************************************/
(
	@message varchar(255) = '' output,
	@MinGANETFitOverride real = -1,					-- Set to 0 or greater to override the GANET_Fit_Minimum_Average_GANET setting in T_Process_Config
	@MinGANETRSquaredOverride real = -1,			-- Set to 0 or greater to override the GANET_RSquared_Minimum_Average_GANET setting in T_Process_Config
	@GANETWeightedAverageOverride smallint = -1,	-- Set to 0 to force GANET Weighted Averaging off and to 1 to force it on; leave at -1 to look up value in T_Process_Config
	@MaxObsAreaInJobEnabledOverride smallint = -1,	-- Set to 0 to force use of the peptide with the maximum observed area in a job off and to 1 to force it on; leave at -1 to look up value in T_Process_Config,
	@infoOnly tinyint = 0
)
AS

	Set NoCount On

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Set @message = ''
	
	Declare @SamplingSize int,
			@OldMassTagsCount int,
			@NewMassTagsCount int,
			@MassTagsCountWithNET int,
			@WeightedAverageEnabled smallint,
			@MaxObsAreaInJobEnabled smallint,
			@MinNETFit real,
			@MinNETRSquared real
			
	Set @SamplingSize = 0
	Set @OldMassTagsCount = 0
	Set @NewMassTagsCount = 0
	Set @MassTagsCountWithNET = 0

	Declare @AvgNETShift float
	Set @AvgNETShift = 0

	declare @lastProgressUpdate datetime
	Set @lastProgressUpdate = GetDate()

	declare @ProgressUpdateIntervalThresholdSeconds int
	Set @ProgressUpdateIntervalThresholdSeconds = 120
	
	If @GANETWeightedAverageOverride >=0
	Begin
		-----------------------------------------------
		-- The GANET weighted average setting has been overridden
		-----------------------------------------------
		--
		If @GANETWeightedAverageOverride = 0
			Set @WeightedAverageEnabled = 0
		Else
			Set @WeightedAverageEnabled = 1
	End
	Else
	Begin
		-----------------------------------------------
		-- Lookup the GANET weighted average setting in T_Process_Config
		-----------------------------------------------
		--
		Set @WeightedAverageEnabled = -1
		
		SELECT TOP 1 @WeightedAverageEnabled = Convert(smallint, Value)
		FROM T_Process_Config
		WHERE [Name] = 'GANET_Weighted_Average_Enabled' AND Len(Value) > 0
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0 Or @myRowCount <> 1
		Begin
			Set @message = 'Error looking up GANET_Weighted_Average_Enabled value in T_Process_Config'
			If @myError = 0
				Set @myError = 50000
			Goto Done
		End
		
		If @WeightedAverageEnabled <> 0
			Set @WeightedAverageEnabled = 1
	End


	If @MaxObsAreaInJobEnabledOverride >=0
	Begin
		-----------------------------------------------
		-- The max observed area in job setting has been overridden
		-----------------------------------------------
		--
		If @MaxObsAreaInJobEnabledOverride = 0
			Set @MaxObsAreaInJobEnabled = 0
		Else
			Set @MaxObsAreaInJobEnabled = 1
	End
	Else
	Begin
		-----------------------------------------------
		-- Lookup the max observed area in job setting in T_Process_Config
		-----------------------------------------------
		--
		Set @MaxObsAreaInJobEnabled = -1
		
		SELECT TOP 1 @MaxObsAreaInJobEnabled = Convert(smallint, Value)
		FROM T_Process_Config
		WHERE [Name] = 'GANET_Avg_Use_Max_Obs_Area_In_Job_Enabled' AND Len(Value) > 0
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0 Or @myRowCount <> 1
		Begin
			Set @message = 'Error looking up GANET_Avg_Use_Max_Obs_Area_In_Job_Enabled value in T_Process_Config'
			If @myError = 0
				Set @myError = 50000
			Goto Done
		End
		
		If @MaxObsAreaInJobEnabled <> 0
			Set @MaxObsAreaInJobEnabled = 1
	End
	
	
	If @MinGANETFitOverride >=0
	Begin
		-----------------------------------------------
		-- The minimum GANET fit setting has been overridden
		-----------------------------------------------
		--
		Set @MinNETFit = @MinGANETFitOverride
	End
	Else
	Begin
		-----------------------------------------------
		-- Lookup the minimum GANET fit setting in T_Process_Config
		-----------------------------------------------
		--
		Set @MinNETFit = -1
		
		SELECT TOP 1 @MinNETFit = Convert(real, Value)
		FROM T_Process_Config
		WHERE [Name] = 'GANET_Fit_Minimum_Average_GANET' AND Len(Value) > 0
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0
		Begin
			Set @message = 'Error looking up GANET_Fit_Minimum_Average_GANET value in T_Process_Config'
			If @myError = 0
				Set @myError = 50001
			Goto Done
		End
		
	End

	If @MinGANETRSquaredOverride >=0
	Begin
		-----------------------------------------------
		-- The minimum GANET R-Squared setting has been overridden
		-----------------------------------------------
		--
		Set @MinNETRSquared = @MinGANETRSquaredOverride
	End
	Else
	Begin
		-----------------------------------------------
		-- Lookup the minimum GANET R-Squared setting in T_Process_Config
		-----------------------------------------------
		--
		Set @MinNETRSquared = -1
		
		SELECT TOP 1 @MinNETRSquared = Convert(real, Value)
		FROM T_Process_Config
		WHERE [Name] = 'GANET_RSquared_Minimum_Average_GANET' AND Len(Value) > 0
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0
		Begin
			Set @message = 'Error looking up GANET_RSquared_Minimum_Average_GANET value in T_Process_Config'
			If @myError = 0
				Set @myError = 50002
			Goto Done
		End
		
		if @MinNETRSquared > -1
			Set @MinNETFit = -1
		
	End
	
	If @MinNETFit = -1 And @MinNETRSquared = -1
	Begin
		Set @message = 'Error looking up GANET_Fit_Minimum_Average_GANET or GANET_RSquared_Minimum_Average_GANET value in T_Process_Config'
		If @myError = 0
			Set @myError = 50003
		Goto Done
	End
	
	If @infoOnly <> 0
	Begin
		SELECT	@MinNETFit as MinNETFit, 
				@MinNETRSquared as MinNETRSquared,
				@WeightedAverageEnabled as WeightedAverageEnabled,
				@MaxObsAreaInJobEnabled as MaxObsAreaInJobEnabled
		
		
	End
	
	-----------------------------------------------
	-- Count the number of mass tags currently present in T_Mass_Tags_NET
	-----------------------------------------------
	--
	SELECT 	@OldMassTagsCount = Count(Mass_Tag_ID)
	FROM	T_Mass_Tags_NET
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Error counting number of rows in T_Mass_Tags_NET (before addition of new MTs)'
		Goto Done
	End

	-----------------------------------------------
	-- Obtain a random sampling of the GANET values for up to 500000 Mass_Tag_ID's present in T_Mass_Tags_NET
	-- We do this by first populating a temporary table with a random value, the Mass_Tag_ID, and the GANET value
	-----------------------------------------------
	--
	SELECT	(RAND(Mass_Tag_ID + DATEPART(ms, GETDATE()))) AS RandKey, Mass_Tag_ID, Avg_GANET
	INTO	#MTIDRandomized
	FROM	T_Mass_Tags_NET
	WHERE NOT Avg_GANET IS NULL

	-- Store the Mass_Tag_ID and Avg_GANET values for the sampling of Mass_Tags in a new temp table		
	SELECT	TOP 500000 Mass_Tag_ID, Avg_GANET, convert(float, 0) AS New_Avg_GANET
	INTO	#GANETSampling
	FROM	#MTIDRandomized
	ORDER BY RandKey
	--
	Set @SamplingSize = @@RowCount

/*
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#NET_Stats_by_Dataset]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#NET_Stats_by_Dataset]
	
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#NET_Stats]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#NET_Stats]
*/

	-----------------------------------------------
	-- Populate a temporary table with the Mass Tags and their 
	--  observed NET values, choosing the best occurrence of each 
	--  peptide in each job using the Max_Obs_Area_in_Job field
	-- Note that analysis jobs are rolled up to the dataset level
	--  to avoid weighting the data on datasets with multiple jobs
	-----------------------------------------------

	CREATE TABLE #NET_Stats_by_Dataset (
		Mass_Tag_ID int,
		Dataset_ID int,							-- A given dataset could have multiple analysis jobs; we're aggregating the data across jobs by dataset
		ScanNum_NET real NULL,
		ScanTime_NET real NULL,
		DiscriminantScoreNorm real,
		Score_NET_Product float NULL,			-- Product of DiscriminantScoreNorm and NET; used in computing weighted average
		Score_NETDiff_Product float NULL,		-- Product of DiscriminantScoreNorm and (NET - NET_Avg)^2; used in computing standard error of NET_Avg
		SNP_Div_ScoreSumMinusScore float NULL	-- Score_NETDiff_Product divided by [Sum(DiscriminantScoreNorm) - DiscriminantScoreNorm]
	)
	
	CREATE UNIQUE CLUSTERED INDEX IX_TempTable_NET_Stats_by_Dataset ON #NET_Stats_by_Dataset (Mass_Tag_ID, Dataset_ID)
	CREATE NONCLUSTERED INDEX IX_TempTable_NET_Stats_by_Dataset2 ON #NET_Stats_by_Dataset (Mass_Tag_ID, ScanNum_NET)
	CREATE NONCLUSTERED INDEX IX_TempTable_NET_Stats_by_Dataset3 ON #NET_Stats_by_Dataset (Mass_Tag_ID, ScanTime_NET)

	-----------------------------------------------
	-- Populate a temporary table with stats for each mass tag,
	-- including average NET (weighted average if @WeightedAverageEnabled = 1)
	-----------------------------------------------
	
	CREATE TABLE #NET_Stats (
		Mass_Tag_ID int,
		NET_Min real,
		NET_Max real,
		NET_Avg float,						-- Average or weighted average discriminant score for given mass tag
		NET_Cnt int,
		NET_StDev float NULL,				-- StDev if not weighting, or unbiased StDev of the Weighted Average if we are weighting
		NET_StDev_Biased float NULL,		-- Biased StDev
		NET_StandardError float NULL,			-- Unbiased standard error
		NET_StandardError_Biased float NULL,	-- Biased standard error
		DiscriminantScore_Sum float NULL,	-- Sum of the discriminant scores for given mass tag; for computation of Weighted_Variance and weighted standard error
		DiscriminantScore_Max float NULL	-- Max of the discriminant scores for the given mass tag; for computation of weighted standard error
	)

	CREATE UNIQUE CLUSTERED INDEX IX_TempTable_GANET_Stats ON #NET_Stats (Mass_Tag_ID)


	-----------------------------------------------
	-- Equations for computing weighted average NET, weighted variance, and standard error
	--
	-- Given normalized elution times, t1, t2, ... tn
	-- and given discriminant scores, d1, d2, ... dn
	--
	-- Compute a weighted average time, T_WAvg = Sum(di*ti) / Sum(di)
	--
	-- Compute a weighted, biased variance,       s^2 = Sum(di*(ti-T_Wavg)^2) / Sum(di)          (From Kevin Anderson)
	-- or, compute a weighted, unbiased variance, s^2 = Sum[di*(ti-T_Wavg)^2) / (Sum(di)-di)]    (From Vlad Petyuk)
	--
	
	-- Optionally, compute the standard error of the weighted average, se = [Sqrt(max(di)) / Sqrt(sum(di))]*s	(From Kevin Anderson)
	-- where s = Sqrt(weighted variance) = Sqrt(s^2)
	-----------------------------------------------

	-----------------------------------------------
	-- <A> Populate relevant columns in #NET_Stats_by_Dataset
	--
	
	-- Note, we are no longer recomputing NET_Obs using the Slope and Intercept values in T_Analysis_Description
	-- Instead, we're using the GANET_Obs value from T_Peptides
	Declare @UseJobSlopeAndIntercept tinyint
	Set @UseJobSlopeAndIntercept = 0
	
	Declare @MaxObsAreaInJobComparison tinyint
	If @MaxObsAreaInJobEnabled = 0
		Set @MaxObsAreaInJobComparison = 0
	Else
		Set @MaxObsAreaInJobComparison = 1
		
	If @UseJobSlopeAndIntercept = 1
		INSERT INTO #NET_Stats_by_Dataset (
			Mass_Tag_ID, Dataset_ID, ScanNum_NET, ScanTime_NET, DiscriminantScoreNorm
			)
		SELECT	Mass_Tag_ID, Dataset_ID, 
				Avg(ScanNum_NET) AS ScanNum_NETAvg, 
				Avg(ScanTime_NET) AS ScanTime_NETAvg, 
				Max(MaxDiscriminantScoreNorm) AS MaxDiscriminantScoreNorm
		FROM (
			SELECT	BestObsQ.Mass_Tag_ID,
					TAD.Dataset_ID,
					BestObsQ.Job,
					CASE WHEN IsNull(TAD.GANET_Slope, 0) > 0
					THEN BestObsQ.BestScanNum * TAD.GANET_Slope + TAD.GANET_Intercept
					ELSE NULL
					END AS ScanNum_NET,
					CASE WHEN IsNull(TAD.ScanTime_NET_Slope, 0) > 0
					THEN BestObsQ.BestScanTime * TAD.ScanTime_NET_Slope + TAD.ScanTime_NET_Intercept
					ELSE NULL
					END AS ScanTime_NET,
					Max(IsNull(SD.DiscriminantScoreNorm, 0.001)) AS MaxDiscriminantScoreNorm
			FROM  (	SELECT	Job, Mass_Tag_ID, 
							MIN(Scan_Number) AS BestScanNum, 
							MIN(Scan_Time_Peak_Apex) AS BestScanTime
					FROM T_Peptides
					WHERE Max_Obs_Area_In_Job >= @MaxObsAreaInJobComparison
					GROUP BY Job, Mass_Tag_ID
					) AS BestObsQ INNER JOIN T_Analysis_Description AS TAD ON
					BestObsQ.Job = TAD.Job INNER JOIN T_Peptides ON
					BestObsQ.Job = T_Peptides.Job AND
					BestObsQ.Mass_Tag_ID = T_Peptides.Mass_Tag_ID AND
					BestObsQ.BestScanNum = T_Peptides.Scan_Number
					LEFT OUTER JOIN T_Score_Discriminant AS SD ON
					T_Peptides.Peptide_ID = SD.Peptide_ID
			WHERE	T_Peptides.Max_Obs_Area_In_Job >= @MaxObsAreaInJobComparison AND
					( IsNull(TAD.GANET_Fit, 0) >= IsNull(@MinNETFit, -1) And 
					  IsNull(TAD.GANET_RSquared, 0) >= IsNull(@MinNETRSquared, -1) And
					  IsNull(TAD.GANET_Slope, 0) > 0
					) OR
					( IsNull(TAD.ScanTime_NET_Fit, 0) >= IsNull(@MinNETFit, -1) And 
					  IsNull(TAD.ScanTime_NET_RSquared, 0) >= IsNull(@MinNETRSquared, -1) And
					  IsNull(TAD.ScanTime_NET_Slope, 0) > 0
					)
			GROUP BY BestObsQ.Mass_Tag_ID, TAD.Dataset_ID, BestObsQ.Job, BestObsQ.BestScanNum,
					BestObsQ.BestScanTime, TAD.GANET_Slope, TAD.GANET_Intercept,
					TAD.ScanTime_NET_Slope, TAD.ScanTime_NET_Intercept
			) AS LookupQ
		GROUP BY Mass_Tag_ID, Dataset_ID
	Else
		INSERT INTO #NET_Stats_by_Dataset (
			Mass_Tag_ID, Dataset_ID, ScanNum_NET, ScanTime_NET, DiscriminantScoreNorm
			)
		SELECT	BestObsQ.Mass_Tag_ID,
				TAD.Dataset_ID,
				Null AS ScanNum_NET,
				Avg(BestNETObs) As NETAvg,
				Max(IsNull(SD.DiscriminantScoreNorm, 0.001)) AS MaxDiscriminantScoreNorm
		FROM  (	SELECT	Job, Mass_Tag_ID, 
						MIN(Scan_Number) AS BestScanNum, 
						MIN(GANET_Obs) AS BestNETObs
				FROM T_Peptides
				WHERE Max_Obs_Area_In_Job >= @MaxObsAreaInJobComparison AND NOT GANET_Obs Is Null
				GROUP BY Job, Mass_Tag_ID
				) AS BestObsQ INNER JOIN T_Analysis_Description AS TAD ON
				BestObsQ.Job = TAD.Job INNER JOIN T_Peptides ON
				BestObsQ.Job = T_Peptides.Job AND
				BestObsQ.Mass_Tag_ID = T_Peptides.Mass_Tag_ID AND
				BestObsQ.BestScanNum = T_Peptides.Scan_Number
				LEFT OUTER JOIN T_Score_Discriminant AS SD ON
				T_Peptides.Peptide_ID = SD.Peptide_ID
		WHERE	T_Peptides.Max_Obs_Area_In_Job >= @MaxObsAreaInJobComparison AND
			    ( IsNull(TAD.GANET_Fit, 0) >= IsNull(@MinNETFit, -1) And 
				  IsNull(TAD.GANET_RSquared, 0) >= IsNull(@MinNETRSquared, -1) And
				  IsNull(TAD.GANET_Slope, 0) > 0
				) OR
				( IsNull(TAD.ScanTime_NET_Fit, 0) >= IsNull(@MinNETFit, -1) And 
				  IsNull(TAD.ScanTime_NET_RSquared, 0) >= IsNull(@MinNETRSquared, -1) And
				  IsNull(TAD.ScanTime_NET_Slope, 0) > 0
				)
		GROUP BY BestObsQ.Mass_Tag_ID, TAD.Dataset_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Error populating #NET_Stats_by_Dataset'
		Goto Done
	End

	if DateDiff(second, @lastProgressUpdate, GetDate()) >= @ProgressUpdateIntervalThresholdSeconds
	Begin
		set @message = '...Processing: Populated #NET_Stats_by_Dataset (' + convert(varchar(19), @myRowCount) + ' total rows)'
		execute PostLogEntry 'Progress', @message, 'ComputeMassTagsGANET'
		set @message = ''
		set @lastProgressUpdate = GetDate()
	End


	-----------------------------------------------
	-- Populate the ScanTime_NET column with the NET values we want to use
	-- 
	UPDATE #NET_Stats_by_Dataset
	SET ScanTime_NET = ScanNum_NET
	WHERE ScanTime_NET Is Null AND NOT ScanNum_NET Is Null
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--


	If @WeightedAverageEnabled =1
	Begin
		-----------------------------------------------
		-- <1-B> Populate relevant columns in #NET_Stats_by_Dataset
		--

		UPDATE #NET_Stats_by_Dataset
		SET Score_NET_Product = ScanTime_NET * DiscriminantScoreNorm
		WHERE NOT ScanTime_NET IS NULL
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		
		-----------------------------------------------
		-- <1-C> Populate relevant columns in #NET_Stats
		--
		
		INSERT INTO #NET_Stats (
			Mass_Tag_ID, NET_Min, NET_Max,
			NET_Avg, NET_Cnt, DiscriminantScore_Sum, DiscriminantScore_Max
		)
		SELECT	Mass_Tag_ID,
				MIN(ScanTime_NET) AS NET_Min, 
				MAX(ScanTime_NET) AS NET_Max, 
				CASE WHEN SUM(DiscriminantScoreNorm) > 0
				THEN SUM(Score_NET_Product) / SUM(DiscriminantScoreNorm)
				ELSE 0
				END NET_Avg,
				COUNT(ScanTime_NET) AS NET_Cnt,
				SUM(DiscriminantScoreNorm) AS DiscriminantScore_Sum,
				MAX(DiscriminantScoreNorm) AS DiscriminantScore_Max
		FROM #NET_Stats_by_Dataset
		WHERE NOT ScanTime_NET IS NULL
		GROUP BY Mass_Tag_ID
		--
		SELECT @myError = @myError + @@error, @myRowCount = @@rowcount

		if DateDiff(second, @lastProgressUpdate, GetDate()) >= @ProgressUpdateIntervalThresholdSeconds
		Begin
			set @message = '...Processing: Populated #NET_Stats (' + convert(varchar(19), @myRowCount) + ' total rows)'
			execute PostLogEntry 'Progress', @message, 'ComputeMassTagsGANET'
			set @message = ''
			set @lastProgressUpdate = GetDate()
		End

		-----------------------------------------------
		-- <1-D> Compute Score_NETDiff_Product
		--

		UPDATE #NET_Stats_by_Dataset
		SET Score_NETDiff_Product = DiscriminantScoreNorm * SQUARE(ScanTime_NET - #NET_Stats.NET_Avg)
		FROM #NET_Stats_by_Dataset INNER JOIN #NET_Stats ON
			 #NET_Stats_by_Dataset.Mass_Tag_ID = #NET_Stats.Mass_Tag_ID
		WHERE NOT #NET_Stats_by_Dataset.ScanTime_NET IS NULL
		--
		SELECT @myError = @myError + @@error, @myRowCount = @@rowcount


		-----------------------------------------------
		-- <1-E> Compute SNP_Div_ScoreSumMinusScore
		--
		
		UPDATE #NET_Stats_by_Dataset
		SET SNP_Div_ScoreSumMinusScore = CASE WHEN #NET_Stats.DiscriminantScore_Sum - DiscriminantScoreNorm = 0 THEN 0
										 ELSE Score_NETDiff_Product / (#NET_Stats.DiscriminantScore_Sum - DiscriminantScoreNorm)
										 END
		FROM #NET_Stats_by_Dataset INNER JOIN #NET_Stats ON
			 #NET_Stats_by_Dataset.Mass_Tag_ID = #NET_Stats.Mass_Tag_ID
		WHERE NOT #NET_Stats_by_Dataset.DiscriminantScoreNorm IS NULL
		--
		SELECT @myError = @myError + @@error, @myRowCount = @@rowcount

		if DateDiff(second, @lastProgressUpdate, GetDate()) >= @ProgressUpdateIntervalThresholdSeconds
		Begin
			set @message = '...Processing: Computed score values in #NET_Stats_by_Dataset (' + convert(varchar(19), @myRowCount) + ' rows updated)'
			execute PostLogEntry 'Progress', @message, 'ComputeMassTagsGANET'
			set @message = ''
			set @lastProgressUpdate = GetDate()
		End
		
		
		-----------------------------------------------
		-- <1-F> Compute the unbiased and biased StDev values
		--

		UPDATE #NET_Stats
		SET NET_StDev = (
				SELECT Sqrt(SUM(NSD.SNP_Div_ScoreSumMinusScore)) AS NET_StDev
				FROM #NET_Stats_by_Dataset AS NSD INNER JOIN
					#NET_Stats AS NS ON NSD.Mass_Tag_ID = NS.Mass_Tag_ID
				WHERE NOT NSD.ScanTime_NET IS NULL
				GROUP BY NS.Mass_Tag_ID
				HAVING NS.Mass_Tag_ID = #NET_Stats.Mass_Tag_ID)
			,
			NET_StDev_Biased = (
				SELECT Sqrt(SUM(NSD.Score_NETDiff_Product) / NS.DiscriminantScore_Sum) AS NET_StDev_Biased
				FROM #NET_Stats_by_Dataset AS NSD INNER JOIN
					#NET_Stats AS NS ON NSD.Mass_Tag_ID = NS.Mass_Tag_ID
				WHERE NOT NSD.ScanTime_NET IS NULL AND
					NS.DiscriminantScore_Sum > 0
				GROUP BY NS.Mass_Tag_ID, NS.DiscriminantScore_Sum
				HAVING NS.Mass_Tag_ID = #NET_Stats.Mass_Tag_ID)
		WHERE NET_Cnt > 1
		--
		SELECT @myError = @myError + @@error, @myRowCount = @@rowcount


		-----------------------------------------------
		-- <1-G> Compute the unbiased and biased Standard Error values
		--
		
		UPDATE #NET_Stats
		SET NET_StandardError = Sqrt(DiscriminantScore_Max) / Sqrt(DiscriminantScore_Sum) * NET_StDev,
			NET_StandardError_Biased = Sqrt(DiscriminantScore_Max) / Sqrt(DiscriminantScore_Sum) * NET_StDev_Biased
		WHERE DiscriminantScore_Sum > 0 AND NET_Cnt > 1
		--
		SELECT @myError = @myError + @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0
		Begin
			Set @message = 'Error populating NET_StDev in #NET_Stats using a weighted standard deviation (steps 1-B through 1-G)'
			Goto Done
		End

		if DateDiff(second, @lastProgressUpdate, GetDate()) >= @ProgressUpdateIntervalThresholdSeconds
		Begin
			set @message = '...Processing: Computed standard error values in #NET_Stats (' + convert(varchar(19), @myRowCount) + ' rows updated)'
			execute PostLogEntry 'Progress', @message, 'ComputeMassTagsGANET'
			set @message = ''
			set @lastProgressUpdate = GetDate()
		End

	End
	Else
	Begin
		-----------------------------------------------
		-- <2-B> Populate relevant columns in #NET_Stats
		--
	
		INSERT INTO #NET_Stats (
			Mass_Tag_ID, NET_Min, NET_Max, 
			NET_Avg, NET_Cnt, NET_StDev)
		SELECT	Mass_Tag_ID,
				MIN(ScanTime_NET) AS NET_Min, 
				MAX(ScanTime_NET) AS NET_Max, 
				AVG(ScanTime_NET) AS NET_Avg,
				COUNT(ScanTime_NET) AS NET_Cnt, 
				STDEV(ScanTime_NET) AS NET_StDev
		FROM #NET_Stats_by_Dataset
		WHERE NOT ScanTime_NET IS NULL
		GROUP BY Mass_Tag_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		if DateDiff(second, @lastProgressUpdate, GetDate()) >= @ProgressUpdateIntervalThresholdSeconds
		Begin
			set @message = '...Processing: Populated #NET_Stats (' + convert(varchar(19), @myRowCount) + ' total rows)'
			execute PostLogEntry 'Progress', @message, 'ComputeMassTagsGANET'
			set @message = ''
			set @lastProgressUpdate = GetDate()
		End

	End

	-----------------------------------------------
	-- Make sure the NET_StDev and NET_StandardError values are 0
	-- for entries with 1 or fewer observations
	--
	UPDATE #NET_Stats
	SET NET_StDev = 0, NET_StDev_Biased = 0,
		NET_StandardError = 0, NET_StandardError_Biased = 0
	WHERE NET_Cnt <= 1
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
			

	If @infoOnly = 0
	Begin
		-----------------------------------------------
		-- Start a transaction
		-----------------------------------------------
		--
		declare @transName varchar(32)
		set @transName = 'ComputeMassTagsGANET'
		begin transaction @transName

		
		-----------------------------------------------
		-- Clear the existing GANET values in T_Mass_Tag_NET
		-----------------------------------------------
		-- 
		UPDATE T_Mass_Tags_NET WITH (TABLOCKX)
		SET Min_GANET = NULL, 
			Max_GANET = NULL, 
			Avg_GANET = NULL,
			Cnt_GANET = NULL, 
			StD_GANET = NULL
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0
		Begin
			rollback transaction @transName
			Set @message = 'Error setting existing Ganet values to NULL in T_Mass_Tags_NET'
			Goto Done
		End

		-----------------------------------------------
		-- Add missing Mass_Tag_IDs to T_Mass_Tags_NET	
		-----------------------------------------------
		-- 
		INSERT INTO T_Mass_Tags_NET WITH (TABLOCKX)
			(Mass_Tag_ID)
		SELECT MT.Mass_Tag_ID
		FROM T_Mass_Tags AS MT LEFT OUTER JOIN T_Mass_Tags_NET AS MTN ON 
			MT.Mass_Tag_ID = MTN.Mass_Tag_ID
		WHERE MT.Internal_Standard_Only = 0 AND MTN.Mass_Tag_ID IS Null
		ORDER BY MT.Mass_Tag_ID
		--		
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0
		Begin
			rollback transaction @transName
			Set @message = 'Error adding missing Mass_Tag_ID values to T_Mass_Tags_NET'
			Goto Done
		End

		-----------------------------------------------
		-- Count the new number of mass tags present in T_Mass_Tags_NET
		-----------------------------------------------
		-- 
		SELECT 	@NewMassTagsCount = Count(Mass_Tag_ID)
		FROM	T_Mass_Tags_NET
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0 OR @myRowCount <> 1
		Begin
			rollback transaction @transName
			Set @message = 'Error counting number of rows in T_Mass_Tags_NET (after addition of new MTs)'
			If @myError = 0
				Set @myError = 50004
			Goto Done
		End


		-----------------------------------------------
		-- Populate T_Mass_Tags_NET with the GANET Stats
		-----------------------------------------------
		--
		UPDATE T_Mass_Tags_NET
		SET Min_GANET = NET_Min, 
			Max_GANET = NET_Max, 
			Avg_GANET = NET_Avg,
			Cnt_GANET = NET_Cnt, 
			--StD_GANET = IsNull(NET_StDev, 0)
			StD_GANET = IsNull(NET_StDev_Biased, 0),
			StdError_GANET = IsNull(NET_StandardError, 0)
		FROM T_Mass_Tags_NET INNER JOIN #NET_Stats ON 
			T_Mass_Tags_NET.Mass_Tag_ID = #NET_Stats.Mass_Tag_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
			

		IF @myError <> 0
			Begin
				rollback transaction @transName
				Set @message = 'Error while populating T_Mass_Tags_NET'
				GOTO Done
			End
		Else
			Begin
				commit transaction @transName
				Set @message = 'Updated T_Mass_Tags_NET; Mass Tags added = ' + convert(varchar(9), (@NewMassTagsCount - @OldMassTagsCount))
				Set @message = @message + '; Rows updated = ' + convert(varchar(9), @NewMassTagsCount)
			End

		
		-----------------------------------------------------------
		-- Invalidate any cached histograms with Mode 0 = NET Histogram
		-----------------------------------------------------------
		Exec UpdateCachedHistograms @HistogramModeFilter = 0, @InvalidateButDoNotProcess=1

		-----------------------------------------------
		-- Count the number of mass tags with Null GANET values
		-----------------------------------------------
		-- 
		SELECT @MassTagsCountWithNET = Count(Mass_Tag_ID)
		FROM T_Mass_Tags_NET
		WHERE NOT Avg_GANET IS NULL
		--
		Set @message = @message + '; Rows with NET values = ' + convert(varchar(9), @MassTagsCountWithNET)
	End
	
	If @SamplingSize > 0
	Begin
		If @infoOnly <> 0
		Begin
			-- Store the new Avg_GANET values in #GANETSampling
			UPDATE #GANETSampling
			SET New_Avg_GANET = #NET_Stats.NET_Avg
			FROM #GANETSampling INNER JOIN #NET_Stats 
			      ON #GANETSampling.Mass_Tag_ID = #NET_Stats.Mass_Tag_ID
		End
		Else
		Begin
			-- Store the new Avg_GANET values in #GANETSampling
			UPDATE #GANETSampling
			SET New_Avg_GANET = T_Mass_Tags_NET.Avg_GANET
			FROM #GANETSampling INNER JOIN T_Mass_Tags_NET
			      ON #GANETSampling.Mass_Tag_ID = T_Mass_Tags_NET.Mass_Tag_ID
		End

		-- Compute the average shift (absolute change) in the Avg_GANET value
		SELECT @AvgNETShift = Avg(Avg_GANET - New_Avg_GANET)
		FROM #GANETSampling
		WHERE NOT (Avg_GANET IS NULL OR New_Avg_GANET IS NULL)
				
		-- Append @AvgNETShift to @message
		Set @message = @message + '; Average NET shift = ' + convert(varchar(9), IsNull(Round(@AvgNETShift, 6), 0))
		-- Append @SamplingSize to @message
		Set @message = @message + '; Sample size = ' + convert(varchar(9), @SamplingSize)
	End
	Else
		Set @message = @message + '; All NET values were previously null -- could not compute average NET shift'

	-- Append comment on @MaxObsAreaInJobEnabled to @message
	If @MaxObsAreaInJobEnabled = 0
		Set @message = @message + '; Using first occurrence of each peptide'
	Else
		Set @message = @message + '; Using peptide obs with maximum area'


	If @infoOnly = 0
		-----------------------------------------------
		-- Post @message to the log
		-----------------------------------------------
		EXEC PostLogEntry 'Normal', @message, 'ComputeMassTagsGANET'
	Else
	Begin		
		SELECT @message AS Processing_Message	
		
		SELECT * 
		FROM #NET_Stats
		ORDER BY Mass_Tag_ID
	End
	
Done:

	Return @MyError

GO
GRANT VIEW DEFINITION ON [dbo].[ComputeMassTagsGANET] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ComputeMassTagsGANET] TO [MTS_DB_Lite] AS [dbo]
GO
