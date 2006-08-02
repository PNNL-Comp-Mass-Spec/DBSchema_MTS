SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UpdateGeneralStatistics]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[UpdateGeneralStatistics]
GO


CREATE Procedure dbo.UpdateGeneralStatistics
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
**		Auth: grk
**		Date: 6/28/2001
**			  9/21/2004 mem - Updated for new MTDB schema
**			  9/29/2004 mem - Added Previous_Value column to T_General_Statistics
**			 10/08/2004 mem - Added PMT quality score-based statistics and more Order By statements
**			 02/05/2005 mem - Switched to using V_Table_Row_Counts for row count stats
**							- Removed count of peptides by State_ID in T_Peptides
**							- Optimized the 'Total PMTs by Organism DB' query
**			 05/20/2005 mem - Updated logic to only use entries from T_Mass_Tags with Internal_Standard_Only = 0
**							- Now listing number of active NET_Locker entries in T_GANET_Lockers
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

	-- Create a temporary table to hold the current statistics
	--
	CREATE TABLE #StatsSaved (
		[Category] [varchar] (128) NULL ,
		[Label] [varchar] (128) NULL ,
		[Value] [varchar] (255) NULL ,
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


	-- Count of PMTs by PMT Quality Score
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT	'Mass Tags' AS category, 
			'PMTs With PMT Quality Score: ' + Convert(varchar(9), PMT_Quality_Score), 
			COUNT(Mass_Tag_ID) AS Value
	FROM T_Mass_Tags
	WHERE Internal_Standard_Only = 0
	GROUP BY PMT_Quality_Score
	ORDER BY PMT_Quality_Score

	-- Count of Modified PMTs by PMT Quality Score
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT	'Mass Tags' AS category, 
			'Modified PMTs With PMT Quality Score: ' + Convert(varchar(9), PMT_Quality_Score), 
			COUNT(Mass_Tag_ID) AS Value
	FROM T_Mass_Tags
	WHERE Internal_Standard_Only = 0 AND Mod_Count > 0
	GROUP BY PMT_Quality_Score
	ORDER BY PMT_Quality_Score


	-- Count of Tryptic PMTs by PMT Quality Score
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT	'Mass Tags' AS category, 
			'Tryptic PMTs With PMT Quality Score: ' + Convert(varchar(9), PMT_Quality_Score), 
			COUNT(Mass_Tag_ID) AS Value
	FROM (	SELECT T_Mass_Tags.PMT_Quality_Score, 
				T_Mass_Tags.Mass_Tag_ID, 
				MAX(T_Mass_Tag_to_Protein_Map.Cleavage_State) AS Cleavage_State_Max
			FROM T_Mass_Tags INNER JOIN
				T_Mass_Tag_to_Protein_Map ON 
				T_Mass_Tags.Mass_Tag_ID = T_Mass_Tag_to_Protein_Map.Mass_Tag_ID
			WHERE Internal_Standard_Only = 0
			GROUP BY T_Mass_Tags.PMT_Quality_Score, T_Mass_Tags.Mass_Tag_ID
		  ) LookupQ
	WHERE (Cleavage_State_Max = 2)
	GROUP BY PMT_Quality_Score
	ORDER BY PMT_Quality_Score


	-- Count of Partially Tryptic PMTs by PMT Quality Score
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT	'Mass Tags' AS category, 
			'Partially Tryptic PMTs With PMT Quality Score: ' + Convert(varchar(9), PMT_Quality_Score), 
			COUNT(Mass_Tag_ID) AS Value
	FROM (	SELECT T_Mass_Tags.PMT_Quality_Score, 
				T_Mass_Tags.Mass_Tag_ID, 
				MAX(T_Mass_Tag_to_Protein_Map.Cleavage_State) AS Cleavage_State_Max
			FROM T_Mass_Tags INNER JOIN
				T_Mass_Tag_to_Protein_Map ON 
				T_Mass_Tags.Mass_Tag_ID = T_Mass_Tag_to_Protein_Map.Mass_Tag_ID
			WHERE Internal_Standard_Only = 0
			GROUP BY T_Mass_Tags.PMT_Quality_Score, T_Mass_Tags.Mass_Tag_ID
		  ) LookupQ
	WHERE (Cleavage_State_Max = 1)
	GROUP BY PMT_Quality_Score
	ORDER BY PMT_Quality_Score


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
	GROUP BY Organism_DB_Name
	ORDER BY Organism_DB_Name

	-- total PMTs by organism DB
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT	'Total PMTs by Organism DB' AS category, 
			Organism_DB_Name AS label, 
			PMTCount AS value
	FROM (	SELECT	T_Analysis_Description.Organism_DB_Name, 
					COUNT(DISTINCT T_Peptides.Mass_Tag_ID) AS PMTCount
			FROM T_Peptides INNER JOIN
				 T_Analysis_Description ON T_Peptides.Analysis_ID = T_Analysis_Description.Job
			GROUP BY T_Analysis_Description.Organism_DB_Name
		) As StatsQ
	ORDER BY Label


	-- update parameter file counts
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT 'Total Analyses by Parameter Files' AS category, 
		 Parameter_File_Name AS label, COUNT(*) AS value
	FROM T_Analysis_Description 
	GROUP BY Parameter_File_Name
	ORDER BY Parameter_File_Name


	-- update GANET histogram
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT 
		'GANET Histogram (MSMS) (bins are 0.1 wide)' AS category, 
		'Bin:' + Convert(varchar(6), GANET_Bin) AS label, 
		Match_Count AS value
	FROM V_MassTags_GANETValueRange_Histogram
	ORDER BY GANET_Bin


	-- update active GANET Locker count
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT	'NET Lockers (internal standards)' AS category, 
			'Active NET Locker Count' AS label, 
			COUNT(Seq_ID)
	FROM T_GANET_Lockers
	WHERE GANET_Locker_State = 1


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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[UpdateGeneralStatistics]  TO [DMS_SP_User]
GO

