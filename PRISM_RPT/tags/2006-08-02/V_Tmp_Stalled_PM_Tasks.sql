SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Tmp_Stalled_PM_Tasks]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Tmp_Stalled_PM_Tasks]
GO

CREATE VIEW [dbo].[V_Tmp_Stalled_PM_Tasks]
AS
SELECT dbo.T_Peak_Matching_History.*
FROM dbo.T_Peak_Matching_History INNER JOIN
        (SELECT PM_AssignedProcessorName, 
           MAX(PM_History_ID) AS PM_History_ID_Max
      FROM T_Peak_Matching_History
      WHERE (PM_Start BETWEEN '6/22/2006 1 pm' AND 
           '6/22/2006 4 pm')
      GROUP BY PM_AssignedProcessorName) LookupQ ON 
    dbo.T_Peak_Matching_History.PM_History_ID = LookupQ.PM_History_ID_Max


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

