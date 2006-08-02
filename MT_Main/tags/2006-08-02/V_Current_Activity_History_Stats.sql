SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Current_Activity_History_Stats]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Current_Activity_History_Stats]
GO

CREATE VIEW dbo.V_Current_Activity_History_Stats
AS
SELECT TOP 100 PERCENT Database_Name, 
    ROUND(AVG(Processing_Time_Minutes), 1) 
    AS Processing_Time_Minutes_Avg, 
    ROUND(MIN(Processing_Time_Minutes), 1) 
    AS Processing_Time_Minutes_Min, 
    ROUND(MAX(Processing_Time_Minutes), 1) 
    AS Processing_Time_Minutes_Max, COUNT(Database_Name) 
    AS Cycle_Count
FROM (SELECT Database_Name, Snapshot_Date, 
          DATEDIFF(second, Snapshot_Date, 
          Update_Completion_Date) 
          / 60.0 - Pause_Length_Minutes AS Processing_Time_Minutes
      FROM T_Current_Activity_History) LookupQ
WHERE (Snapshot_Date > GETDATE() - 14)
GROUP BY Database_Name
ORDER BY Database_Name

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

