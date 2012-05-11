/****** Object:  StoredProcedure [dbo].[UpdateGeneralStatistics] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure UpdateGeneralStatistics
/****************************************************
**
**	Desc: Gathers several general statistics from mass
**        tag database and updates their values in the
**        T_General_Statistics table
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	
**
**	Auth:	grk
**	Date:	06/28/2001
**			09/21/2004 mem - Updated for new MTDB schema
**			09/29/2004 mem - Added Previous_Value column to T_General_Statistics
**			10/08/2004 mem - Added PMT quality score-based statistics and more Order By statements
**			02/05/2005 mem - Switched to using V_Table_Row_Counts for row count stats
**						   - Removed count of peptides by State_ID in T_Peptides
**						   - Optimized the 'Total PMTs by Organism DB' query
**			05/20/2005 mem - Updated logic to only use entries from T_Mass_Tags with Internal_Standard_Only = 0
**						   - Now listing number of active NET_Locker entries in T_GANET_Lockers
**			12/15/2005 mem - Removed reference to T_GANET_Lockers
**			03/04/2006 mem - Now considering option GeneralStatisticsIncludesExtendedInfo in T_Process_Step_Control
**			03/13/2006 mem - Switched to reporting stats by minimum PMT Quality Score rather than for each PMT Quality Score
**						   - Added protein stats
**			06/04/2006 mem - Now examining Protein_Collection_List and Protein_Options_List in T_Analysis_Description
**			01/13/2008 mem - Increased field sizes in #StatsSaved
**			04/05/2008 mem - Updated to use Cleavage_State_Max in T_Mass_Tags
**			07/22/2011 mem - Now including Peak Matching Task stats
**			01/06/2012 mem - Updated to use T_Peptides.Job
**    
*****************************************************/
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @MTCount int
	declare @MTCountConfirmed int
	declare @result int
	
	Declare @GeneralStatisticsIncludesExtendedInfo tinyint
	Set @GeneralStatisticsIncludesExtendedInfo = 0

	Declare @MinimumPMTQS real
	Declare @MinimumPMTQSStart real
	Declare @continue tinyint

	-- Lookup the value of GeneralStatisticsIncludesExtendedInfo in T_Process_Step_Control
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'GeneralStatisticsIncludesExtendedInfo')
	if @result > 0
		Set @GeneralStatisticsIncludesExtendedInfo = 1

	
	-- Create a temporary table to hold the current statistics
	--
	CREATE TABLE #StatsSaved (
		[Category] [varchar] (512) NULL ,
		[Label] [varchar] (2048) NULL ,
		[Value] [varchar] (1024) NULL ,
		[Entry_ID] [int] NOT NULL 
	)
	
	INSERT INTO #StatsSaved (Category, Label, Value, Entry_ID)
	SELECT Category, Label, Value, Entry_ID
	FROM T_General_Statistics
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount	
	
	
	-- clear the general statistics table
	--
	DELETE FROM T_General_Statistics
	
	-- Header row
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT 'General' AS category, 'Last Updated' AS label, GetDate() AS value

	
	-- update PMT counts
	--
	-- Count total number of PMTs and total confirmed
	--
	SELECT	@MTCount = COUNT(Mass_Tag_ID), 
			@MTCountConfirmed = SUM(CASE WHEN Is_Confirmed > 0 THEN 1 ELSE 0 END)
	FROM T_Mass_Tags
	WHERE Internal_Standard_Only = 0
	
	-- Store the results
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	VALUES ('Mass Tags', 'PMTs', @MTCount)
	INSERT INTO T_General_Statistics (Category, Label, Value)
	VALUES ('Mass Tags', 'Confirmed PMTs', @MTCountConfirmed)


	-- Stats by minimum PMT Quality Score
	-- Create two temporary tables
	CREATE TABLE #TmpPMTQualityScoreValues (
		PMT_Quality_Score real
	)

	CREATE TABLE #TmpGeneralStatisticsData (
		Stat_ID int,
		PMT_Quality_Score_Minimum real,
		Category varchar(128),
		Label varchar(128),
		Value int
	)

	-- Next, populate the temporary table
	INSERT INTO #TmpPMTQualityScoreValues (PMT_Quality_Score)
	SELECT DISTINCT PMT_Quality_Score
	FROM T_Mass_Tags
	WHERE NOT PMT_Quality_Score IS NULL
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount	

	-- Determine the minimum PMT Quality Score value
	Set @MinimumPMTQSStart = 0
	SELECT @MinimumPMTQSStart = MIN(PMT_Quality_Score)
	FROM #TmpPMTQualityScoreValues
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount	
	
	Set @MinimumPMTQS = @MinimumPMTQSStart
	Set @Continue = 1
	While @Continue = 1
	Begin
		-- Compute the peptides stats for each PMT Quality Score value

		-- Count of PMTs by PMT Quality Score
		--
		INSERT INTO #TmpGeneralStatisticsData (Stat_ID, PMT_Quality_Score_Minimum, Category, Label, Value)
		SELECT	0 AS Stat_ID,
				@MinimumPMTQS AS PMT_Quality_Score_Minimum,
				'Mass Tags' AS category, 
				'PMTs With PMT Quality Score >= ' + Convert(varchar(9), @MinimumPMTQS) AS Label, 
				COUNT(Mass_Tag_ID) AS Value
		FROM T_Mass_Tags
		WHERE Internal_Standard_Only = 0 AND 
			  PMT_Quality_Score >= @MinimumPMTQS
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount	


		-- Count of Modified PMTs by PMT Quality Score
		--
		INSERT INTO #TmpGeneralStatisticsData (Stat_ID, PMT_Quality_Score_Minimum, Category, Label, Value)
		SELECT	1 AS Stat_ID,
				@MinimumPMTQS AS PMT_Quality_Score_Minimum,
				'Mass Tags' AS category, 
				'Modified PMTs With PMT Quality Score >= ' + Convert(varchar(9), @MinimumPMTQS) AS Label, 
				COUNT(Mass_Tag_ID) AS Value
		FROM T_Mass_Tags
		WHERE Internal_Standard_Only = 0 AND Mod_Count > 0 AND 
			  PMT_Quality_Score >= @MinimumPMTQS
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount	


		-- Strict filters peptide count
		INSERT INTO #TmpGeneralStatisticsData (Stat_ID, PMT_Quality_Score_Minimum, Category, Label, Value)
		SELECT	2 AS Stat_ID,
				@MinimumPMTQS AS PMT_Quality_Score_Minimum,
				'Mass Tags' AS category, 
				'PMTs With Obs Count >=4 and PMT Quality Score >= ' + Convert(varchar(9), @MinimumPMTQS) AS Label, 
				COUNT(Mass_Tag_ID) AS Value
		FROM T_Mass_Tags
		WHERE Internal_Standard_Only = 0 AND Peptide_Obs_Count_Passing_Filter >= 4 AND 
			  PMT_Quality_Score >= @MinimumPMTQS
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount	

	      
		If @GeneralStatisticsIncludesExtendedInfo = 1
		Begin
			-- Count of Tryptic PMTs by PMT Quality Score
			--
			INSERT INTO #TmpGeneralStatisticsData (Stat_ID, PMT_Quality_Score_Minimum, Category, Label, Value)
			SELECT	3 AS Stat_ID,
					@MinimumPMTQS AS PMT_Quality_Score_Minimum,
					'Mass Tags' AS category, 
					'Tryptic PMTs With PMT Quality Score >= ' + Convert(varchar(9), @MinimumPMTQS) AS Label, 
					COUNT(Mass_Tag_ID) AS Value
			FROM T_Mass_Tags
			WHERE Internal_Standard_Only = 0 AND Cleavage_State_Max = 2 AND
				  PMT_Quality_Score >= @MinimumPMTQS 
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount	


			-- Count of Partially Tryptic PMTs by PMT Quality Score
			--
			INSERT INTO #TmpGeneralStatisticsData (Stat_ID, PMT_Quality_Score_Minimum, Category, Label, Value)
			SELECT	4 AS Stat_ID,
					@MinimumPMTQS AS PMT_Quality_Score_Minimum,
					'Mass Tags' AS category, 
					'Partially Tryptic PMTs With PMT Quality Score >= ' + Convert(varchar(9), @MinimumPMTQS) AS Label,
					COUNT(Mass_Tag_ID) AS Value
			FROM T_Mass_Tags
			WHERE Internal_Standard_Only = 0 AND Cleavage_State_Max = 1 AND
				  PMT_Quality_Score >= @MinimumPMTQS 
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount	

		End

		-- Lookup next PMT_Quality_Score value		
		SELECT TOP 1 @MinimumPMTQS = PMT_Quality_Score
		FROM #TmpPMTQualityScoreValues
		WHERE PMT_Quality_Score > @MinimumPMTQS
		ORDER BY PMT_Quality_Score
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount	
		
		If @myRowCount = 0
			Set @Continue = 0
	End
	
	-- Copy the new statistics from #TmpGeneralStatisticsData to T_General_Statistics
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT Category, Label, Value
	FROM #TmpGeneralStatisticsData 
	ORDER BY Stat_ID, PMT_Quality_Score_Minimum
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount	

	
	-- Protein count with 1 or more PMT Tag (by MS/MS)
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT	'Proteins' AS category, 
			'Protein Count With at least 1 PMT Tag' AS label, 
			COUNT(DISTINCT MTPM.Ref_ID) AS Value
	FROM T_Mass_Tag_to_Protein_Map MTPM INNER JOIN
		 T_Mass_Tags MT ON MTPM.Mass_Tag_ID = MT.Mass_Tag_ID
	WHERE MT.Internal_Standard_Only = 0
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount	
	
	
	-- Clear #TmpPMTQualityScoreValues
	TRUNCATE Table #TmpGeneralStatisticsData
	
	Set @MinimumPMTQS = @MinimumPMTQSStart
	Set @Continue = 1
	While @Continue = 1
	Begin
		-- Compute the protein stats for each PMT Quality Score value
		
		-- Count of proteins by PMT Quality Score
		--
		INSERT INTO #TmpGeneralStatisticsData (Stat_ID, PMT_Quality_Score_Minimum, Category, Label, Value)
		SELECT	0 AS Stat_ID,
				@MinimumPMTQS AS PMT_Quality_Score_Minimum,
				'Proteins' AS category, 
				'Proteins with Peptide Obs Count >=4 and PMT Quality Score >= ' + Convert(varchar(9), @MinimumPMTQS) AS Label, 
				COUNT(DISTINCT MTPM.Ref_ID) AS Value
		FROM T_Mass_Tag_to_Protein_Map MTPM INNER JOIN
			 T_Mass_Tags MT ON MTPM.Mass_Tag_ID = MT.Mass_Tag_ID
		WHERE MT.Internal_Standard_Only = 0 AND
			  MT.Peptide_Obs_Count_Passing_Filter >= 4 AND
			  MT.PMT_Quality_Score >= @MinimumPMTQS
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount	
		
		
		SELECT TOP 1 @MinimumPMTQS = PMT_Quality_Score
		FROM #TmpPMTQualityScoreValues
		WHERE PMT_Quality_Score > @MinimumPMTQS
		ORDER BY PMT_Quality_Score
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount	
		
		If @myRowCount = 0
			Set @Continue = 0
	End

	-- Copy the new statistics from #TmpGeneralStatisticsData to T_General_Statistics
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT Category, Label, Value
	FROM #TmpGeneralStatisticsData 
	ORDER BY Stat_ID, PMT_Quality_Score_Minimum
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount	


	If @GeneralStatisticsIncludesExtendedInfo = 1
		Begin
		-- update counts for peaks by state
		--
		INSERT INTO T_General_Statistics (Category, Label, Value)
		SELECT	'FTICR UMC Results by State' AS category, 
				Convert(varchar(11), T_FPR_State_Name.Match_State) + ' - ' + T_FPR_State_Name.Match_State_Name AS label, 
				COUNT(*) as value
		FROM T_FTICR_UMC_ResultDetails INNER JOIN
		T_FPR_State_Name ON 
		T_FTICR_UMC_ResultDetails.Match_State = T_FPR_State_Name.Match_State
		GROUP BY T_FPR_State_Name.Match_State_Name, T_FPR_State_Name.Match_State
		ORDER BY T_FPR_State_Name.Match_State
	End


	-- update analyses counts
	--
	-- total MSMS analyses
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT 'Primary Analyses' AS category, 
	   'Number of MSMS Analyses' AS label, COUNT(*) AS value
	FROM T_Analysis_Description
	--
	-- total FTICR analyses
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT 'Primary Analyses' AS category, 
	   'Number of FTICR Analyses' AS label, COUNT(*) AS value
	FROM T_FTICR_Analysis_Description


	-- update analysis tool counts
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT 'Total Analyses by Analysis Tool' AS category, 
		 Analysis_Tool AS label, COUNT(*) AS value
	FROM T_Analysis_Description 
	GROUP BY Analysis_Tool
	ORDER BY Analysis_Tool
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT 'Total Analyses by Analysis Tool' AS category, 
		 Analysis_Tool AS label, COUNT(*) AS value
	FROM T_FTICR_Analysis_Description 
	GROUP BY Analysis_Tool
	ORDER BY Analysis_Tool

	-- update analysis state counts
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT	'MSMS Analyses (non TIC) by State' AS category, 
			Convert(varchar(11), T_Analysis_State_Name.AD_State_ID) + ' - ' + T_Analysis_State_Name.AD_State_Name AS label, 
			COUNT(*) as value
	FROM T_Analysis_Description INNER JOIN
	   T_Analysis_State_Name ON 
	   T_Analysis_Description.State = T_Analysis_State_Name.AD_State_ID
	WHERE Analysis_Tool NOT LIKE '%TIC%'
	GROUP BY T_Analysis_State_Name.AD_State_Name, T_Analysis_State_Name.AD_State_ID
	ORDER BY T_Analysis_State_Name.AD_State_ID
	
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT	'FTICR Analyses (non TIC) by State' AS category, 
			Convert(varchar(11), T_FAD_State_Name.FAD_State_ID) + ' - ' + T_FAD_State_Name.FAD_State_Name AS label,
			COUNT(*) AS value
	FROM T_FTICR_Analysis_Description INNER JOIN
	   T_FAD_State_Name ON 
	  T_FTICR_Analysis_Description.State = T_FAD_State_Name.FAD_State_ID
	WHERE Analysis_Tool NOT LIKE '%TIC%'
	GROUP BY T_FAD_State_Name.FAD_State_Name, T_FAD_State_Name.FAD_State_ID
	ORDER BY T_FAD_State_Name.FAD_State_ID
	
	-- update organism DB counts
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT 'Total Analyses by Organism DB' AS category, 
		 Organism_DB_Name AS label, COUNT(*) AS value
	FROM T_Analysis_Description
	WHERE Organism_DB_Name <> 'na'
	GROUP BY Organism_DB_Name
	ORDER BY Organism_DB_Name

	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT 'Total Analyses by Organism DB' AS category, 
		 Protein_Collection_List + '; ' + Protein_Options_List AS label, COUNT(*) AS value
	FROM T_Analysis_Description
	WHERE Protein_Collection_List <> 'na'
	GROUP BY Protein_Collection_List, Protein_Options_List
	ORDER BY Protein_Collection_List, Protein_Options_List


	If @GeneralStatisticsIncludesExtendedInfo = 1
	Begin
		-- total PMTs by organism DB
		--
		INSERT INTO T_General_Statistics (Category, Label, Value)
		SELECT	'Total PMTs by Organism DB' AS category, 
				Organism_DB_Name AS label, 
				PMTCount AS value
		FROM (	SELECT	T_Analysis_Description.Organism_DB_Name, 
						COUNT(DISTINCT T_Peptides.Mass_Tag_ID) AS PMTCount
				FROM T_Peptides INNER JOIN
					T_Analysis_Description ON T_Peptides.Job = T_Analysis_Description.Job
				GROUP BY T_Analysis_Description.Organism_DB_Name
			) As StatsQ
		ORDER BY Label
	End

	-- update parameter file counts
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT 'Total Analyses by Parameter Files' AS category, 
		 Parameter_File_Name AS label, COUNT(*) AS value
	FROM T_Analysis_Description 
	GROUP BY Parameter_File_Name
	ORDER BY Parameter_File_Name

	-- Update Peak Matching stats by state
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT 'Peak Matching Tasks by State' AS category,
	       CONVERT(varchar(11), PM.Processing_State) + ' - ' + TSN.Processing_State_Name AS Label, 
	       COUNT(*) AS Value
	FROM T_Peak_Matching_Task PM INNER JOIN
		T_Peak_Matching_Task_State_Name TSN ON PM.Processing_State = TSN.Processing_State
	GROUP BY PM.Processing_State, TSN.Processing_State_Name
	ORDER BY PM.Processing_State

	-- Update Peak Matching stats by .Ini file
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT 'Peak Matching Tasks by .Ini File' AS category,
	       Ini_File_Name as Label, COUNT(*) AS Value
	FROM T_Peak_Matching_Task
	WHERE (Processing_State <> 5)
	GROUP BY Ini_File_Name
	ORDER BY Ini_File_Name


	-- update GANET histogram
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT 
		'GANET Histogram (MSMS) (bins are 0.1 wide)' AS category, 
		'Bin:' + Convert(varchar(6), GANET_Bin) AS label, 
		Match_Count AS value
	FROM V_MassTags_GANETValueRange_Histogram
	ORDER BY GANET_Bin


	-- Process_Config entries
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT	'Configuration Settings' AS category, 
			[Name] AS label, 
			Value
	FROM	T_Process_Config 
	ORDER BY [Name]


	-- Populate the Previous_Value column in T_General_Statistics
	--
	UPDATE T_General_Statistics
	SET Previous_Value = (	SELECT TOP 1 Value
							FROM #StatsSaved
							WHERE #StatsSaved.Category = T_General_Statistics.Category AND
								  #StatsSaved.Label = T_General_Statistics.Label
						 )
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount	

Done:
	Return @myError

GO
GRANT EXECUTE ON [dbo].[UpdateGeneralStatistics] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateGeneralStatistics] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateGeneralStatistics] TO [MTS_DB_Lite] AS [dbo]
GO
