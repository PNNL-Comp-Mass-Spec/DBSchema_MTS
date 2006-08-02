SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Analysis_Job_to_MT_DB_Map]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Analysis_Job_to_MT_DB_Map]
GO

CREATE VIEW dbo.V_Analysis_Job_to_MT_DB_Map
AS
SELECT TOP 100 PERCENT AJMDM.Job, AJMDM.ResultType, 
    MIN(MTDB.MTL_Name) AS MTL_Name_First, 
    MAX(MTDB.MTL_Name) AS MTL_Name_Last, 
    COUNT(AJMDM.MTL_ID) AS MTL_Count
FROM dbo.T_Analysis_Job_to_MT_DB_Map AJMDM INNER JOIN
    dbo.T_MT_Database_List MTDB ON 
    AJMDM.MTL_ID = MTDB.MTL_ID
GROUP BY AJMDM.Job, AJMDM.ResultType
ORDER BY AJMDM.Job

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

