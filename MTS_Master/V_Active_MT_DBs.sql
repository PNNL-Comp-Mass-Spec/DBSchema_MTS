/****** Object:  View [dbo].[V_Active_MT_DBs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_Active_MT_DBs]
AS
SELECT S.Server_Name,
       D.MT_DB_Name,
       D.State_ID,
       D.Last_Affected,
       D.[Description],
       D.Organism,
       D.Campaign,
       D.DB_Schema_Version       
FROM dbo.T_MTS_MT_DBs AS D
     INNER JOIN dbo.T_MTS_Servers AS S
       ON D.Server_ID = S.Server_ID
WHERE (S.Active = 1) AND
      (NOT (D.State_ID IN (10, 15, 100)))


GO
