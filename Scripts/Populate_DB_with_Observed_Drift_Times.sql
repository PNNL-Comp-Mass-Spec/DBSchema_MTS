-- Connect to [MT_MinT_Kans_Soil_IMS_P1062] on Roadrunner

--------------------------------
-- If necessary, delete all of the existing conformers
--------------------------------

/*
-- Backup the current conformers
SELECT *, CONVERT(datetime, '1/29/2014') As PM_Date
INTO T_Mass_Tag_Conformers_Observed_Old
FROM T_Mass_Tag_Conformers_Observed

-- Remove conformer information from peak matching results
UPDATE T_FTICR_UMC_ResultDetails
SET Conformer_ID = NULL
WHERE NOT conformer_id IS NULL

-- Clear the conformer tables
DELETE FROM T_Mass_Tag_Conformers_Observed
DELETE FROM dbo.T_Mass_Tag_Conformers_Predicted
*/
GO

--------------------------------
-- Add peak matching tasks
--------------------------------

-- Job list for desired jobs
SELECT IMSJobs.Dataset, IMSJobs.Job
FROM (SELECT *
     FROM T_FTICR_Analysis_Description
     WHERE (Instrument_Class = 'IMS_Agilent_TOF')) IMSJobs INNER JOIN
       (SELECT Experiment, Dataset, Job, Instrument, Instrument_Class
     FROM T_Analysis_Description
     WHERE (Instrument_Class = 'ltq_ft')) OrbiJobs ON IMSJobs.Experiment = OrbiJobs.Experiment
GROUP BY IMSJobs.Experiment, IMSJobs.Dataset, IMSJobs.Job
ORDER BY IMSJobs.job

SELECT * FROM V_PMT_Quality_Score_Report_for_Peak_Matching
SELECT * FROM T_Peak_Matching_Defaults
SELECT * FROM V_Peak_Matching_Task

exec dbo.AddDefaultPeakMatchingTasks 
    @JobListFilter = '1197676,1197750,1197785,1197786,1197787,1198102,1198103,1198113,1198114,1198115,1198116,1198117,1198119,1198120,1198229,1198270,1198271,1198272,1198273,1198274,1198275,1198276,1198277,1198278,1198279,1198280,1198281,1198282,1198283,1198516,1198517,1198518,1198519,1198520,1198521,1198522,1198523,1198524,1198525,1198526,1198527,1198528,1198529,1198530,1198531,1198532,1198533,1198535,1198536,1198537,1198538,1198539,1198540,1198608,1198741', -- varchar(max)
    @SetStateToHolding = 1

SELECT *
FROM V_Peak_Matching_Task
WHERE Job IN (1197676,1197750,1197785,1197786,1197787,1198102,1198103,1198113,1198114,1198115,1198116,1198117,1198119,1198120,1198229,1198270,1198271,1198272,1198273,1198274,1198275,1198276,1198277,1198278,1198279,1198280,1198281,1198282,1198283,1198516,1198517,1198518,1198519,1198520,1198521,1198522,1198523,1198524,1198525,1198526,1198527,1198528,1198529,1198530,1198531,1198532,1198533,1198535,1198536,1198537,1198538,1198539,1198540,1198608,1198741)
ORDER by Task_ID

--------------------------------
-- Define an experiment filter for the new peak matching tasks and enable them for processing
--------------------------------
UPDATE T_Peak_Matching_Task
SET Experiment_Filter = FAD.Experiment,
    Ini_File_Name = 'IMS_PredefinedFeatures_AllMappedPoints_NetAdjWarpTol25ppm_AMT25ppm_0.035NET_NoDT_Export_SaveGraphics_2012-05-21.ini',
	Minimum_PMT_Quality_Score=2,
    Processing_State = 1
FROM T_FTICR_Analysis_Description FAD
     INNER JOIN T_Peak_Matching_Task PM
       ON FAD.Job = PM.Job
WHERE FAD.Job IN (1197676,1197750,1197785,1197786,1197787,1198102,1198103,1198113,1198114,1198115,1198116,1198117,1198119,1198120,1198229,1198270,1198271,1198272,1198273,1198274,1198275,1198276,1198277,1198278,1198279,1198280,1198281,1198282,1198283,1198516,1198517,1198518,1198519,1198520,1198521,1198522,1198523,1198524,1198525,1198526,1198527,1198528,1198529,1198530,1198531,1198532,1198533,1198535,1198536,1198537,1198538,1198539,1198540,1198608,1198741)
      And PM.Processing_State=5

exec dbo.UpdateCachedAnalysisTasksForThisDB


--------------------------------
-- Monitor the progress
--------------------------------
SELECT Processing_State, COUNT(*) AS Task_Count
FROM V_Peak_Matching_Task
GROUP BY Processing_State

GO

--------------------------------
-- Obtain list of MD_IDs to process
--------------------------------
SELECT PM.*,
       MMD.AMT_Count_5pct_FDR,
       MMD.AMT_Count_10pct_FDR,
       MMD.AMT_Count_25pct_FDR
FROM V_Peak_Matching_Task PM
     INNER JOIN T_Match_Making_Description MMD
       ON PM.MD_ID = MMD.MD_ID
WHERE PM.Instrument Like 'IMS%' AND Task_ID Between 1 and 55
ORDER BY PM.MD_ID

SELECT MD_ID
FROM T_Peak_Matching_Task
WHERE (Experiment_Filter <> '')
ORDER BY MD_ID

--------------------------------
-- Process each entry
--------------------------------
Declare @MDIDList varchar(MAX)

-- Use this @MDIDList for peak matching tasks that searched only peptides observed in the same experiment
Set @MDIDList = '1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55'

-- Determine appropriate values for @MaxFDRThreshold and @MinimumUniquenessProbability
Declare @MaxFDRThreshold float = 0.5
Declare @MinimumUniquenessProbability float = 0.5

SELECT FAD.Instrument,
       PM.Dataset,
       PM.Job,
       PM.Ini_File_Name,
       COUNT(DISTINCT FURD.Mass_Tag_ID) AS Unique_AMTs
       -- COUNT(DISTINCT FURD.Conformer_ID) AS Conformers
FROM V_Peak_Matching_Task PM
     INNER JOIN T_Match_Making_Description MMD ON PM.MD_ID = MMD.MD_ID
     INNER JOIN T_FTICR_UMC_Results FUR ON MMD.MD_ID = FUR.MD_ID
     INNER JOIN T_FTICR_UMC_ResultDetails FURD ON FUR.UMC_Results_ID = FURD.UMC_Results_ID
     INNER JOIN T_FTICR_Analysis_Description FAD ON MMD.MD_Reference_Job = FAD.Job
WHERE FUR.MD_ID = 1 And FURD.FDR_Threshold <= @MaxFDRThreshold and FURD.Uniqueness_Probability >= @MinimumUniquenessProbability And FURD.Match_Score >= 0
GROUP BY PM.Dataset, PM.Job, PM.Ini_File_Name, FAD.Instrument
ORDER BY FAD.Instrument, PM.Ini_File_Name, PM.Dataset

-- Note: runtime to process these 55 MD_IDs will be several minutes
exec AddMatchMakingConformersForList
    @MDIDList = @MDIDList,
    @MaxFDRThreshold = 0.5,					-- Adjust this higher if not enough matches
    @MinimumUniquenessProbability = 0.5,
    @DriftTimeTolerance = 2,
	@MergeChargeStates=1,
    @FilterByExperimentMSMS = 0, 
    @InfoOnly = 0,
	@MaxIterations = 0,
	@DriftTimeToleranceFinal=1

	
-- Update table T_Mass_Tag_Conformers_Predicted
exec UpdatePredictedConformers

-- Summarize the conformers
-- This makes histograms of the number of conformers that exist for each AMT tag
SELECT DB_NAME() as ThisDB, ConformerCount, COUNT(*) AS BinCount
FROM (SELECT Mass_Tag_ID, Charge, COUNT(*) AS ConformerCount
      FROM T_Mass_Tag_Conformers_Observed
      GROUP BY Mass_Tag_ID, Charge) LookupQ
GROUP BY ConformerCount
ORDER BY ConformerCount

SELECT * FROM T_Mass_Tag_Conformers_Observed
SELECT * FROM t_log_entries

--------------------------------
-- Peak match the IMS datasets using mass, NET, and IMS drift time
--------------------------------

-- Find the jobs
SELECT Job, Dataset, Instrument
FROM T_FTICR_Analysis_Description
WHERE (Instrument = 'IMS04_AgTOF05')

-- Add the peak matching tasks
Exec AddDefaultPeakMatchingTasks 
    @JobListFilter = '1079091,1079186,1080661,1080695,1080698,1080707,1080708,1080720,1080724,1080725,1080726,1081002,1081003,1081004,1081063,1081068,1081089,1081098,1081099,1081100,1081117,1081145,1081146,1081252,1081347,1081375,1081378,1081379,1081390,1081392,1081393,1081394,1081395,1081396,1081398,1081400,1081402,1081403,1081405,1081407,1081735,1081736,1081738,1081739,1081740,1081741,1081742,1081744,1081753,1081754,1081877,1081882,1085931,1085932,1085933',
    @SetStateToHolding = 1

UPDATE T_Peak_Matching_Task
SET Minimum_PMT_Quality_Score=2,
    Processing_State = 1
FROM T_FTICR_Analysis_Description FAD
     INNER JOIN T_Peak_Matching_Task PM
       ON FAD.Job = PM.Job
WHERE FAD.Job IN (1079091,1079186,1080661,1080695,1080698,1080707,1080708,1080720,1080724,1080725,1080726,1081002,1081003,1081004,1081063,1081068,1081089,1081098,1081099,1081100,1081117,1081145,1081146,1081252,1081347,1081375,1081378,1081379,1081390,1081392,1081393,1081394,1081395,1081396,1081398,1081400,1081402,1081403,1081405,1081407,1081735,1081736,1081738,1081739,1081740,1081741,1081742,1081744,1081753,1081754,1081877,1081882,1085931,1085932,1085933)
      And PM.Processing_State=5

exec dbo.UpdateCachedAnalysisTasksForThisDB


--------------------------------
-- Peak match the Orbitrap and QExactive datasets using mass and NET
--------------------------------

-- Find the jobs
SELECT Job, Dataset
FROM T_FTICR_Analysis_Description
WHERE NOT Instrument LIKE 'ims%'

-- Add the peak matching tasks
Exec AddDefaultPeakMatchingTasks 
    @JobListFilter = '1065901,1065905,1065906,1065907,1065908,1065909,1065910,1065911,1065912,1065913,1065914,1065915,1065916,1065917,1065918,1065919,1065920,1065921,1065922,1065923,1065924,1065925,1065926,1065927,1065928,1065929,1065930,1065931,1065932,1065933,1065934,1065935,1065936,1065937,1065939,1065940,1065941,1065942,1065943,1065944,1065945,1065946,1065947,1065948,1065949,1065950,1065952,1066413,1066414,1078950,1078952,1087680,1087682,1087684,1088170,1088171,1088175',
    @SetStateToHolding = 1

UPDATE T_Peak_Matching_Task
SET Minimum_PMT_Quality_Score=2,
    Processing_State = 1
FROM T_FTICR_Analysis_Description FAD
     INNER JOIN T_Peak_Matching_Task PM
       ON FAD.Job = PM.Job
WHERE FAD.Job IN (1065901,1065905,1065906,1065907,1065908,1065909,1065910,1065911,1065912,1065913,1065914,1065915,1065916,1065917,1065918,1065919,1065920,1065921,1065922,1065923,1065924,1065925,1065926,1065927,1065928,1065929,1065930,1065931,1065932,1065933,1065934,1065935,1065936,1065937,1065939,1065940,1065941,1065942,1065943,1065944,1065945,1065946,1065947,1065948,1065949,1065950,1065952,1066413,1066414,1078950,1078952,1087680,1087682,1087684,1088170,1088171,1088175)
      And PM.Processing_State=5

exec dbo.UpdateCachedAnalysisTasksForThisDB

