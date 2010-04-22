/****** Object:  View [dbo].[V_MTS_MT_DBs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_MTS_MT_DBs]
AS
SELECT M.MT_DB_ID,
       M.MT_DB_Name,
       S.Server_Name,
       M.State_ID,
       DBStates.Name AS State,
       M.Last_Affected,
       M.[Description],
       M.Organism,
       M.Campaign,
       M.DB_Schema_Version,
       M.[Comment],
       M.Created,
       S.Active AS Server_Active
FROM dbo.T_MTS_MT_DBs AS M
     INNER JOIN dbo.T_MTS_Servers AS S
       ON M.Server_ID = S.Server_ID
     LEFT OUTER JOIN MT_Main.dbo.T_MT_Database_State_Name AS DBStates
       ON M.State_ID = DBStates.ID


GO
