SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[MassTagAccumulationTrend]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[MassTagAccumulationTrend]
GO


CREATE PROCEDURE dbo.MassTagAccumulationTrend
/****************************************************
**
**	Desc: 
**		Generates data showing number of PMT Tags
**		present over time in given DB
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 05/24/2005
**			  08/17/2005 mem - Now rounding TAD.Dataset_Created_DMS to the nearest date in the PMT Creation Stats query
**    
*****************************************************/
(
	@MinimumPMTQualityScore real = 1,
	@MinimumHighDiscriminantScore real = 0
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
			
	--------------------------------------------------------------
	-- Create a temporary table to hold the histogrammed PMT creation dates
	--------------------------------------------------------------
	--
	CREATE TABLE #CreationHistogram (
		Created datetime,
		PMTTagCountCurrentDate int
	)

	--------------------------------------------------------------
	-- Bin the PMT Tags by minimum DMS creation date (rounded to a resolution of one day)
	--------------------------------------------------------------
	--	
	INSERT INTO #CreationHistogram (Created, PMTTagCountCurrentDate)
	SELECT	CONVERT(datetime, Created) AS Created, 
			COUNT(*) AS PMTTagCountCurrentDate
	FROM (	SELECT Pep.Mass_Tag_ID, MIN(CONVERT(int, TAD.Dataset_Created_DMS)) AS Created
			FROM	T_Analysis_Description TAD INNER JOIN
					T_Peptides Pep ON TAD.Job = Pep.Analysis_ID INNER JOIN
					T_Mass_Tags MT ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID
			WHERE PMT_Quality_Score >= @MinimumPMTQualityScore AND
					High_Discriminant_Score >= @MinimumHighDiscriminantScore
			GROUP BY Pep.Mass_Tag_ID			
		 ) LookupQ
	GROUP BY Created
	ORDER BY Created
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	
	--------------------------------------------------------------
	-- Generate the PMT Creation Stats (in the inner query named PMTCreationStats)
	-- Link in a running total of the number of jobs to date (using the outer query)
	--------------------------------------------------------------
	--	
	SELECT	PMTCreationStats.Created, 
			COUNT(TAD.Job) AS JobsToDate, 
			PMTCreationStats.TotalPMTsToDate
	FROM T_Analysis_Description TAD CROSS JOIN
			(	SELECT A.Created, SUM(B.PMTTagCountCurrentDate) AS TotalPMTsToDate
				FROM #CreationHistogram A CROSS JOIN
					 #CreationHistogram B
				WHERE B.Created <= A.Created
				GROUP BY A.Created
			 ) PMTCreationStats
	WHERE CONVERT(datetime, CONVERT(int, TAD.Dataset_Created_DMS)) <= PMTCreationStats.Created
	GROUP BY PMTCreationStats.Created, PMTCreationStats.TotalPMTsToDate
	ORDER BY PMTCreationStats.Created
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


Done:
	Return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[MassTagAccumulationTrend]  TO [DMS_SP_User]
GO

