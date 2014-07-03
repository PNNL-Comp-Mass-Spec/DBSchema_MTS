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
       M.Last_Online,
       M.[Description],
       M.Organism,
       M.Campaign,
       M.DB_Schema_Version,
       M.[Comment],
       M.Created,
       S.Active AS Server_Active,
       PDM.Peptide_DB,
       PDBC.Peptide_DB_Count
FROM dbo.T_MTS_MT_DBs M
     INNER JOIN dbo.T_MTS_Servers S
       ON M.Server_ID = S.Server_ID
     LEFT OUTER JOIN MT_Main.dbo.T_MT_Database_State_Name DBStates
       ON M.State_ID = DBStates.ID
     LEFT OUTER JOIN V_MTS_MTDB_to_PeptideDB_Map PDM
       ON M.MT_DB_Name = PDM.MT_DB_Name AND
          ISNULL(PDM.PeptideDBNum, 1) = 1
     LEFT OUTER JOIN ( SELECT MT_DB_Name,
                              COUNT(*) AS Peptide_DB_Count
                       FROM V_MTS_MTDB_to_PeptideDB_Map
                       WHERE Not Peptide_DB Is Null
                       GROUP BY MT_DB_Name ) PDBC
       ON M.MT_DB_Name = PDBC.MT_DB_Name



GO
