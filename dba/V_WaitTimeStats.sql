/****** Object:  View [dbo].[V_WaitTimeStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_WaitTimeStats]
As
SELECT RollupQ.CheckDate,
       RollupQ.WaitTimeRatio,
       RollupQ.WaitTimeSecThisPeriod,
       RollupQ.ElapsedSec,
       RollupQ.WaitStatus,
       CASE
           WHEN WaitTimeRatio > RollupQ.WaitTimeRatioNoCLR * 2 THEN 
              'Common Language Runtime processes caused the high waits; ignoring the CLR, the WaitTimeRatio is ' + Cast(WaitTimeRatioNoCLR AS varchar(12))
           ELSE ''
       END AS AddnlInfo
FROM ( SELECT ComparisonQ.CheckDate,
              -- WaitTimeRatio is the ratio of WaitTime to WallClock time; a ratio means for every elapsed hour, the server spends 1 hour waiting on things
              Cast(ComparisonQ.WaitTimeSecThisPeriod / ComparisonQ.ElapsedSec AS decimal(9, 2)) AS WaitTimeRatio,
              Cast(ComparisonQ.WaitTimeSecNoCLRThisPeriod / ComparisonQ.ElapsedSec AS decimal(9, 2)) AS WaitTimeRatioNoCLR,
              ComparisonQ.WaitTimeSecThisPeriod,
              ComparisonQ.ElapsedSec,
              CASE
                  WHEN ComparisonQ.WaitTimeSecThisPeriod / ComparisonQ.ElapsedSec > 1.00 THEN 
                    'Ratio > 1: massive wait times'
                  WHEN ComparisonQ.WaitTimeSecThisPeriod / ComparisonQ.ElapsedSec > 0.75 THEN 
                    'Ratio > 0.75: significant wait times'
                  WHEN ComparisonQ.WaitTimeSecThisPeriod / ComparisonQ.ElapsedSec > 0.50 THEN 
                    'Ratio > 0.50: large wait times'
                  WHEN ComparisonQ.WaitTimeSecThisPeriod / ComparisonQ.ElapsedSec > 0.25 THEN 
                    'Ratio > 0.25: moderate wait times'
                  ELSE '' -- Minimal wait times
              END AS WaitStatus
       FROM ( SELECT CheckDate,
                     WaitTimeSec - Lag(StatsQ.WaitTimeSec, 1) OVER ( ORDER BY StatsQ.CheckDate ) AS WaitTimeSecThisPeriod,
                     WaitTimeSecNoCLR - Lag(StatsQ.WaitTimeSecNoCLR, 1) OVER ( ORDER BY StatsQ.CheckDate ) AS WaitTimeSecNoCLRThisPeriod,
                     DateDiff(SECOND, Lag(StatsQ.CheckDate, 1) OVER ( ORDER BY StatsQ.CheckDate ), CheckDate) AS ElapsedSec
              FROM ( SELECT Cast(CheckDate AS datetime) AS CheckDate,
                            Cast(Sum([wait_time_ms] / 1000.0) AS decimal(9, 0)) AS WaitTimeSec,
                            Cast(Sum(Case WHEN wait_type = 'CLR_AUTO_EVENT' THEN 0 ELSE [wait_time_ms] END / 1000.0) AS decimal(9, 0)) AS WaitTimeSecNoCLR
                     FROM dbo.BlitzFirst_WaitStats
                     GROUP BY Cast(CheckDate AS datetime) 
                    ) StatsQ 
            ) ComparisonQ
       WHERE ComparisonQ.WaitTimeSecThisPeriod > 0 
) RollupQ


GO
