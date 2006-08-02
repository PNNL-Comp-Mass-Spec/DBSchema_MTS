SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_PeakMatching_Tasks_Stalled]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_PeakMatching_Tasks_Stalled]
GO

CREATE VIEW dbo.V_PeakMatching_Tasks_Stalled
AS
SELECT TOP 100 PERCENT *
FROM (SELECT LookupQ.PM_AssignedProcessorName, 
          LookupQ.Working, 
          MostRecentTaskQ.PM_Finish_Max AS MostRecentFinish,
           DATEDIFF(hour, ISNULL(LookupQ.PM_Finish, 
          LookupQ.PM_Start), 
          MostRecentTaskQ.PM_Finish_Max) 
          AS HoursSinceMostRecentFinish, DATEDIFF(hour, 
          LookupQ.PM_Start, ISNULL(LookupQ.PM_Finish, 
          GETDATE())) AS ProcessingTimeHoursElapsed
      FROM (SELECT PM_Activity.*
            FROM T_Peak_Matching_Processors PM_Processors INNER
                 JOIN
                T_Peak_Matching_Activity PM_Activity ON 
                PM_Processors.PM_AssignedProcessorName = PM_Activity.PM_AssignedProcessorName
            WHERE (PM_Processors.Active = 1)) 
          LookupQ CROSS JOIN
              (SELECT MAX(PM_Finish) AS PM_Finish_Max
            FROM T_Peak_Matching_Activity
            WHERE NOT PM_Finish IS NULL) MostRecentTaskQ) 
    OuterQ
WHERE (Working = 1) AND 
    (ProcessingTimeHoursElapsed > 20) OR
    (HoursSinceMostRecentFinish > 36) AND (DATEDIFF(hour, 
    MostRecentFinish, GETDATE()) > 4)
ORDER BY PM_AssignedProcessorName

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

