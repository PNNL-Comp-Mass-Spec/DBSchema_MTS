/****** Object:  View [dbo].[V_Peak_Matching_History_By_Day] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Peak_Matching_History_By_Day
AS
SELECT TOP (100) PERCENT Tool_ID, Tool_Name, 
    CONVERT(datetime, CONVERT(varchar(4), TheYear) 
    + '/' + CONVERT(varchar(4), TheMonth) 
    + '/' + CONVERT(varchar(4), TheDay)) AS Date, 
    MatchCount
FROM (SELECT AJ.Tool_ID, Tool.Tool_Name, DATEPART(year, 
          AJ.Job_Start) AS TheYear, DATEPART(month, 
          AJ.Job_Start) AS TheMonth, DATEPART(day, 
          AJ.Job_Start) AS TheDay, COUNT(AJ.Job_ID) 
          AS MatchCount
      FROM dbo.T_Analysis_Job AS AJ INNER JOIN
          dbo.T_Analysis_Tool AS Tool ON 
          AJ.Tool_ID = Tool.Tool_ID
      GROUP BY AJ.Tool_ID, Tool.Tool_Name, DATEPART(day, 
          AJ.Job_Start), DATEPART(year, AJ.Job_Start), 
          DATEPART(month, AJ.Job_Start)) AS LookupQ
ORDER BY date

GO
