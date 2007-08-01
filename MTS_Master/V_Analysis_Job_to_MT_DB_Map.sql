/****** Object:  View [dbo].[V_Analysis_Job_to_MT_DB_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Analysis_Job_to_MT_DB_Map
AS
SELECT TOP (100) PERCENT S.Server_Name, AJMDM.Job, 
    AJMDM.ResultType, ISNULL(D.MT_DB_Name, '??') 
    AS DB_Name, AJMDM.Last_Affected, CONVERT(varchar(12), 
    AJMDM.Process_State) + ': ' + ISNULL(StateName.Name, '??') 
    AS Process_State
FROM dbo.T_Analysis_Job_to_MT_DB_Map AS AJMDM INNER JOIN
    dbo.T_MTS_Servers AS S ON 
    AJMDM.Server_ID = S.Server_ID LEFT OUTER JOIN
    dbo.T_Analysis_Job_MT_DB_State_Name AS StateName ON 
    AJMDM.Process_State = StateName.ID LEFT OUTER JOIN
    dbo.T_MTS_MT_DBs AS D ON 
    AJMDM.MT_DB_ID = D.MT_DB_ID AND 
    AJMDM.Server_ID = D.Server_ID
ORDER BY AJMDM.Job, DB_Name, S.Server_Name

GO
