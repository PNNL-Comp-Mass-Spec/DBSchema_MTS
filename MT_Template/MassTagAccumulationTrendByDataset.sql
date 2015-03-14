/****** Object:  StoredProcedure [dbo].[MassTagAccumulationTrendByDataset] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE MassTagAccumulationTrendByDataset
/****************************************************
**
**	Desc: 
**		Generates data showing number of PMT Tags
**		present over time in given DB.  Stats are returned
**		on a dataset-by-dataset basis, ordering by
**		Dataset_Acq_Time_Start
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	05/08/2009 -- Modelled after MassTagAccumulationTrend
**			01/06/2012 mem - Updated to use T_Peptides.Job
**    
*****************************************************/
(
	@MinimumPMTQualityScore real = 1,
	@MinimumHighDiscriminantScore real = 0,
	@MinimumPeptideProphetProbability real = 0
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @Sql varchar(8000)

	--------------------------------------------------------------
	-- Validate the inputs
	--------------------------------------------------------------
	--
	Set @MinimumPMTQualityScore = IsNull(@MinimumPMTQualityScore, 0)
	
	Set @MinimumHighDiscriminantScore = IsNull(@MinimumHighDiscriminantScore, 0)
	If @MinimumHighDiscriminantScore < 0
		Set @MinimumHighDiscriminantScore= 0
	If @MinimumHighDiscriminantScore > 1
		Set @MinimumHighDiscriminantScore = 1

	Set @MinimumPeptideProphetProbability = IsNull(@MinimumPeptideProphetProbability, 0)
	If @MinimumPeptideProphetProbability < 0
		Set @MinimumPeptideProphetProbability= 0
	If @MinimumPeptideProphetProbability > 1
		Set @MinimumPeptideProphetProbability = 1

	--------------------------------------------------------------
	-- Create a temporary table to hold the first Dataset_ID in which each MTID was observed
	--------------------------------------------------------------
	--
	--IF EXISTS (SELECT * FROM sys.tables WHERE Name = '#TmpCreationHistogram')
	--	Drop Table #TmpCreationHistogram
		
	CREATE TABLE #TmpCreationHistogram (
		Entry_ID int IDENTITY(1,1),
		Dataset_ID int,
		DatasetAcqTime datetime,
		PMTTagCountNewThisDataset int,
		PMTTagObsCount int NULL,
		PMTTagCountDistinct int NULL,
		JobCount int NULL
	)

	--------------------------------------------------------------
	-- Bin the PMT Tags by Dataset_ID
	--------------------------------------------------------------
	--	
	INSERT INTO #TmpCreationHistogram (Dataset_ID, DatasetAcqTime, PMTTagCountNewThisDataset)
	SELECT Dataset_ID,
	       Dataset_Acq_Time,
	       COUNT(*) AS PMTTagCountNewThisDataset
	FROM ( SELECT Mass_Tag_ID,
	              Dataset_ID,
	              Dataset_Acq_Time
	       FROM ( SELECT Pep.Mass_Tag_ID,
	                     Dataset_ID,
	                     IsNull(TAD.Dataset_Acq_Time_Start, TAD.Dataset_Created_DMS) AS Dataset_Acq_Time,
	                     Row_Number() OVER ( PARTITION BY Pep.Mass_Tag_ID ORDER BY 
	                                         IsNull(TAD.Dataset_Acq_Time_Start, TAD.Dataset_Created_DMS) ) AS DatasetObsRank
	              FROM T_Analysis_Description TAD
	                   INNER JOIN T_Peptides Pep
	                     ON TAD.Job = Pep.Job
	                   INNER JOIN T_Mass_Tags MT
	                     ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID
	              WHERE (MT.PMT_Quality_Score >= @MinimumPMTQualityScore) AND
	                    (MT.High_Discriminant_Score >= @MinimumHighDiscriminantScore) AND
	                    (MT.High_Peptide_Prophet_Probability >= @MinimumPeptideProphetProbability) 
	             ) FilterQ
	       WHERE DatasetObsRank = 1 
	     ) LookupQ
	GROUP BY Dataset_ID, Dataset_Acq_Time
	ORDER BY Dataset_Acq_Time
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	--------------------------------------------------------------
	-- Populate the additional columns in #TmpCreationHistogram
	--------------------------------------------------------------
	--	
	UPDATE #TmpCreationHistogram
	SET PMTTagObsCount = StatsQ.PMTTagObsCount,
	    PMTTagCountDistinct = StatsQ.PMTTagCountDistinct,
	    JobCount = StatsQ.JobCount
	FROM #TmpCreationHistogram
	     INNER JOIN ( SELECT TAD.Dataset_ID,
	        COUNT(Pep.Mass_Tag_ID) AS PMTTagObsCount,
	                         COUNT(DISTINCT Pep.Mass_Tag_ID) AS PMTTagCountDistinct,
	                         COUNT(DISTINCT TAD.Job) AS JobCount
	                  FROM T_Analysis_Description TAD
	                       INNER JOIN T_Peptides Pep
	                         ON TAD.Job = Pep.Job
	                       INNER JOIN T_Mass_Tags MT
	                         ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID
	                  WHERE (MT.PMT_Quality_Score >= @MinimumPMTQualityScore) AND
	                        (MT.High_Discriminant_Score >= @MinimumHighDiscriminantScore) AND
	                        (MT.High_Peptide_Prophet_Probability >= @MinimumPeptideProphetProbability)
	                  GROUP BY TAD.Dataset_ID ) StatsQ
	       ON #TmpCreationHistogram.Dataset_ID = StatsQ.Dataset_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


	
	--------------------------------------------------------------
	-- Generate the PMT Creation Stats (in the inner query named PMTCreationStats)
	-- Link in a running total of the number of datasets and jobs that contributed to those stats (using the query named TotalsQ)
	-- Finally, link in #TmpCreationHistogram to return the final data
	--------------------------------------------------------------
	--	
	SELECT DISTINCT TotalsQ.*,
	       H.PMTTagObsCount,
	       H.PMTTagCountDistinct,
	       H.PMTTagCountNewThisDataset,
	       H.Dataset_ID AS Newest_Dataset_ID,
	       TAD.Dataset AS Newest_Dataset,
	       H.DatasetAcqTime,
	       H.JobCount
	FROM ( SELECT PMTCreationStats.Entry_ID,
	              PMTCreationStats.TotalPMTsToDate,
	              COUNT(DISTINCT DSJ.Dataset) AS DatasetCount,
	              COUNT(DISTINCT DSJ.Job) AS JobCount
	       FROM ( SELECT H.Entry_ID,
	                     TAD.Dataset,
	                     TAD.Job
	              FROM #TmpCreationHistogram H
	                   INNER JOIN T_Analysis_Description TAD
	                     ON H.Dataset_ID = TAD.Dataset_ID ) DSJ
	            INNER JOIN ( SELECT A.Entry_ID,
	                                SUM(B.PMTTagCountNewThisDataset) AS TotalPMTsToDate
	                         FROM #TmpCreationHistogram A
	                              CROSS JOIN #TmpCreationHistogram B
	                         WHERE B.Entry_ID <= A.Entry_ID
	                         GROUP BY A.Entry_ID 
	                       ) PMTCreationStats
	              ON DSJ.Entry_ID <= PMTCreationStats.Entry_ID
	       GROUP BY PMTCreationStats.Entry_ID, PMTCreationStats.TotalPMTsToDate 
	     ) TotalsQ
	     INNER JOIN #TmpCreationHistogram H
	       ON TotalsQ.Entry_ID = H.Entry_ID
	     INNER JOIN T_Analysis_Description TAD
	       ON H.Dataset_ID = TAD.Dataset_ID
	ORDER BY Entry_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[MassTagAccumulationTrendByDataset] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[MassTagAccumulationTrendByDataset] TO [MTS_DB_Lite] AS [dbo]
GO
