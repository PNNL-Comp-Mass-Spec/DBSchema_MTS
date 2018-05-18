/****** Object:  View [dbo].[BlitzFirst_PerfmonStats2_Deltas] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[BlitzFirst_PerfmonStats2_Deltas] AS 
WITH RowDates as
(
        SELECT 
                ROW_NUMBER() OVER (ORDER BY [CheckDate]) ID,
                [CheckDate]
        FROM [dbo].[BlitzFirst_PerfmonStats2]
        GROUP BY [CheckDate]
),
CheckDates as
(
        SELECT ThisDate.CheckDate,
               LastDate.CheckDate as PreviousCheckDate
        FROM RowDates ThisDate
        JOIN RowDates LastDate
        ON ThisDate.ID = LastDate.ID + 1
)
SELECT
       pMon.[ServerName]
      ,pMon.[CheckDate]
      ,pMon.[object_name]
      ,pMon.[counter_name]
      ,pMon.[instance_name]
      ,DATEDIFF(SECOND,pMonPrior.[CheckDate],pMon.[CheckDate]) AS ElapsedSeconds
      ,pMon.[cntr_value]
      ,pMon.[cntr_type]
      ,(pMon.[cntr_value] - pMonPrior.[cntr_value]) AS cntr_delta
 ,(pMon.cntr_value - pMonPrior.cntr_value) * 1.0 / DATEDIFF(ss, pMonPrior.CheckDate, pMon.CheckDate) AS cntr_delta_per_second
  FROM [dbo].[BlitzFirst_PerfmonStats2] pMon
  INNER HASH JOIN CheckDates Dates
  ON Dates.CheckDate = pMon.CheckDate
  JOIN [dbo].[BlitzFirst_PerfmonStats2] pMonPrior
  ON  Dates.PreviousCheckDate = pMonPrior.CheckDate
      AND pMon.[ServerName]    = pMonPrior.[ServerName]   
      AND pMon.[object_name]   = pMonPrior.[object_name]  
      AND pMon.[counter_name]  = pMonPrior.[counter_name] 
      AND pMon.[instance_name] = pMonPrior.[instance_name]
    WHERE DATEDIFF(MI, pMonPrior.CheckDate, pMon.CheckDate) BETWEEN 1 AND 60;
GO
