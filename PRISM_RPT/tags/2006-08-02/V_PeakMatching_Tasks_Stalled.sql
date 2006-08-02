SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_PeakMatching_Tasks_Stalled]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_PeakMatching_Tasks_Stalled]
GO

CREATE VIEW [dbo].[V_PeakMatching_Tasks_Stalled]
AS
SELECT TOP 100 PERCENT *
FROM (SELECT LookupQ.PM_AssignedProcessorName, 
          LookupQ.PM_ToolQueryDate, LookupQ.Working, 
          DATEDIFF(hour, LookupQ.PM_ToolQueryDate, GetDate()) 
          AS HoursSinceLastQuery, DATEDIFF(hour, 
          LookupQ.PM_Start, ISNULL(LookupQ.PM_Finish, 
          GETDATE())) AS ProcessingTimeHoursElapsed
      FROM (SELECT PM_Activity.PM_AssignedProcessorName, 
                PM_Activity.Working, PM_Activity.PM_Start, 
                PM_Activity.PM_Finish, 
                ISNULL(PM_Activity.PM_ToolQueryDate, 
                ISNULL(PM_Activity.PM_Finish, 
                PM_Activity.PM_Start)) 
                AS PM_ToolQueryDate
            FROM T_Peak_Matching_Processors PM_Processors INNER
                 JOIN
                T_Peak_Matching_Activity PM_Activity ON 
                PM_Processors.PM_AssignedProcessorName = PM_Activity.PM_AssignedProcessorName
            WHERE (PM_Processors.Active = 1)) LookupQ) 
    OuterQ
WHERE (Working = 1) AND 
    (ProcessingTimeHoursElapsed > 20) OR
    (Working = 0) AND (HoursSinceLastQuery > 24)
ORDER BY PM_AssignedProcessorName


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

