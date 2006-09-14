/****** Object:  View [dbo].[V_Analysis_Job_to_Peptide_DB_Map_Summary] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Analysis_Job_to_Peptide_DB_Map_Summary
AS
SELECT TOP (100) PERCENT SummaryQ.Server_Name, 
    SummaryQ.Job, SummaryQ.ResultType, 
    SummaryQ.DB_Name_First, SummaryQ.DB_Name_Last, 
    SummaryQ.DB_Count, CONVERT(varchar(12), 
    SummaryQ.Process_State_Min) 
    + ': ' + ISNULL(MinStateName.Name, '??') 
    AS Process_State_Min, CONVERT(varchar(12), 
    SummaryQ.Process_State_Max) 
    + ': ' + ISNULL(MaxStateName.Name, '??') 
    AS Process_State_Max, SummaryQ.Last_Affected
FROM (SELECT TOP (100) PERCENT Server_Name, Job, 
          ResultType, MIN(DB_Name) AS DB_Name_First, 
          MAX(DB_Name) AS DB_Name_Last, COUNT(DB_Name) 
          AS DB_Count, MIN(Process_State) 
          AS Process_State_Min, MAX(Process_State) 
          AS Process_State_Max, MAX(Last_Affected) 
          AS Last_Affected
      FROM (SELECT S.Server_Name, AJPDM.Job, 
                AJPDM.ResultType, 
                ISNULL(dbo.T_MTS_Peptide_DBs.Peptide_DB_Name,
                 '??') AS DB_Name, AJPDM.Last_Affected, 
                AJPDM.Process_State
            FROM dbo.T_Analysis_Job_to_Peptide_DB_Map AS AJPDM
                 INNER JOIN
                dbo.T_MTS_Servers AS S ON 
                AJPDM.Server_ID = S.Server_ID LEFT OUTER JOIN
                dbo.T_MTS_Peptide_DBs ON 
                AJPDM.Peptide_DB_ID = dbo.T_MTS_Peptide_DBs.Peptide_DB_ID
                 AND 
                AJPDM.Server_ID = dbo.T_MTS_Peptide_DBs.Server_ID)
           AS LookupQ
      GROUP BY Server_Name, Job, ResultType) 
    AS SummaryQ LEFT OUTER JOIN
    dbo.T_Analysis_Job_Peptide_DB_State_Name AS MinStateName
     ON 
    SummaryQ.Process_State_Min = MinStateName.ID LEFT OUTER
     JOIN
    dbo.T_Analysis_Job_Peptide_DB_State_Name AS MaxStateName
     ON 
    SummaryQ.Process_State_Max = MaxStateName.ID
ORDER BY SummaryQ.Job, SummaryQ.Server_Name

GO
