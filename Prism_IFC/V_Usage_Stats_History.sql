/****** Object:  View [dbo].[V_Usage_Stats_History] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Usage_Stats_History
AS
SELECT TOP 100 PERCENT Posted_By, Posting_Date, 
    MAX(Usage_Count) AS Usage_Count_by_Day
FROM (SELECT Posted_By, CONVERT(datetime, 
          FLOOR(CONVERT(real, Posting_time))) 
          AS Posting_Date, Usage_Count
      FROM dbo.T_Usage_Log
      WHERE (NOT (Usage_Count IS NULL))
      GROUP BY Posted_By, Posting_time, Usage_Count) 
    LookupQ
GROUP BY Posted_By, Posting_Date
ORDER BY Posted_By, Posting_Date

GO
