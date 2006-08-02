SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Peak_Matching_History_By_Day]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Peak_Matching_History_By_Day]
GO

CREATE VIEW dbo.V_Peak_Matching_History_By_Day
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

