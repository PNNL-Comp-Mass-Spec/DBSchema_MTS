/****** Object:  View [dbo].[V_MultiAlign_Tasks_Stalled] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_MultiAlign_Tasks_Stalled]
AS
SELECT TOP 100 PERCENT *
FROM ( SELECT LookupQ.Assigned_Processor_Name,
              LookupQ.Tool_Query_Date,
              LookupQ.Working,
              DATEDIFF(HOUR, LookupQ.Tool_Query_Date, GetDate()) AS HoursSinceLastQuery,
              DATEDIFF(HOUR, LookupQ.Task_Start, ISNULL(LookupQ.Task_Finish, GETDATE())) AS 
                ProcessingTimeHoursElapsed
       FROM ( SELECT MAA.Assigned_Processor_Name,
                     MAA.Working,
                     MAA.Task_Start,
                     MAA.Task_Finish,
                     ISNULL(MAA.Tool_Query_Date, ISNULL(MAA.Task_Finish, MAA.Task_Start)) AS 
                       Tool_Query_Date
              FROM T_MultiAlign_Activity MAA
                   LEFT OUTER JOIN T_Analysis_Job_Processors AJP
                     ON MAA.Assigned_Processor_Name = AJP.Processor_Name
              WHERE (IsNull(AJP.State, 'D') = 'E') ) LookupQ ) OuterQ
WHERE (Working = 1) AND
      (ProcessingTimeHoursElapsed > 20) OR
      (Working = 0) AND
      (HoursSinceLastQuery > 24)
ORDER BY Assigned_Processor_Name


GO
