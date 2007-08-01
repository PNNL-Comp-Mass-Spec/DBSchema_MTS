/****** Object:  View [dbo].[V_MT_DBs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_MT_DBs
AS
SELECT TOP 100 PERCENT S.Server_Name,
    M.MT_DB_ID, 
    M.MT_DB_Name, 
    M.State_ID, 
    M.Last_Affected, 
    M.DB_Schema_Version
FROM dbo.T_MTS_MT_DBs M INNER JOIN
    dbo.T_MTS_Servers S ON M.Server_ID = S.Server_ID
WHERE (S.Active = 1) AND (M.State_ID < 15)


GO
