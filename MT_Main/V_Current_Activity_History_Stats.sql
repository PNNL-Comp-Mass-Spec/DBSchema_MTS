/****** Object:  View [dbo].[V_Current_Activity_History_Stats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_Current_Activity_History_Stats]
AS
SELECT TOP 100 PERCENT Database_Name,
                       ROUND(AVG(Processing_Time_Minutes), 1) AS Processing_Time_Minutes_Avg,
                       ROUND(MIN(Processing_Time_Minutes), 1) AS Processing_Time_Minutes_Min,
                       ROUND(MAX(Processing_Time_Minutes), 1) AS Processing_Time_Minutes_Max,
                       COUNT(Database_Name) AS Cycle_Count,
                       Convert(decimal(9,2), SUM(Processing_Time_Minutes)) AS Processing_Time_Minutes_Total_LastTwoWeeks
FROM ( SELECT Database_Name,
              Snapshot_Date,
              DATEDIFF(SECOND, Snapshot_Date, Update_Completion_Date) / 60.0 - Pause_Length_Minutes 
                AS Processing_Time_Minutes
       FROM T_Current_Activity_History ) LookupQ
WHERE (Snapshot_Date > GETDATE() - 14)
GROUP BY Database_Name
ORDER BY Database_Name


GO
