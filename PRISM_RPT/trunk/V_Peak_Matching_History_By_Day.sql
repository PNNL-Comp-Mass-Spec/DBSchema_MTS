/****** Object:  View [dbo].[V_Peak_Matching_History_By_Day] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_Peak_Matching_History_By_Day]
AS
SELECT TOP 100 PERCENT CONVERT(datetime, 
    CONVERT(varchar(4), TheYear) + '/' + CONVERT(varchar(4), 
    TheMonth) + '/' + CONVERT(varchar(4), TheDay)) AS Date, 
    MatchCount
FROM (SELECT DATEPART(year, PM_Start) AS TheYear, 
          DATEPART(month, PM_Start) AS TheMonth, 
          DATEPART(day, PM_Start) AS TheDay, 
          COUNT(PM_History_ID) AS MatchCount
      FROM T_Peak_Matching_History
      GROUP BY DATEPART(day, PM_Start), DATEPART(year, 
          PM_Start), DATEPART(month, PM_Start)) 
    LookupQ
ORDER BY date


GO
