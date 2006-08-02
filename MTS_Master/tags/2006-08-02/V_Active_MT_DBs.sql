SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Active_MT_DBs]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Active_MT_DBs]
GO

CREATE VIEW dbo.V_Active_MT_DBs
AS
SELECT TOP 100 PERCENT dbo.T_MTS_Servers.Server_Name, 
    dbo.T_MTS_MT_DBs.MT_DB_Name, 
    dbo.T_MTS_MT_DBs.State_ID, 
    dbo.T_MTS_MT_DBs.Last_Affected, 
    dbo.T_MTS_MT_DBs.DB_Schema_Version
FROM dbo.T_MTS_MT_DBs INNER JOIN
    dbo.T_MTS_Servers ON 
    dbo.T_MTS_MT_DBs.Server_ID = dbo.T_MTS_Servers.Server_ID
WHERE (dbo.T_MTS_Servers.Active = 1) AND 
    (NOT (dbo.T_MTS_MT_DBs.State_ID IN (10, 15, 100)))
ORDER BY dbo.T_MTS_Servers.Server_Name, 
    dbo.T_MTS_MT_DBs.MT_DB_Name

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

