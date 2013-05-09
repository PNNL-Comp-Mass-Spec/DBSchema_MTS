/****** Object:  View [dbo].[V_MTS_MTDB_to_PeptideDB_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE VIEW [dbo].[V_MTS_MTDB_to_PeptideDB_Map]
AS

SELECT M.MT_DB_ID,
       M.MT_DB_Name,
       S.Server_Name,
       GSC.[Value] AS Peptide_DB,
       Row_Number() OVER (Partition By M.MT_DB_ID, M.MT_DB_Name, S.Server_Name ORDER BY GSC.[value]) as PeptideDBNum
FROM dbo.T_MTS_MT_DBs M
     INNER JOIN dbo.T_MTS_Servers S
       ON M.Server_ID = S.Server_ID
     LEFT OUTER JOIN MT_Main.dbo.T_MT_Database_State_Name DBStates
       ON M.State_ID = DBStates.ID
     LEFT OUTER JOIN T_General_Statistics_Cached GSC
       ON M.MT_DB_Name = GSC.DBName AND
          GSC.Label = 'Peptide_DB_Name'




GO
