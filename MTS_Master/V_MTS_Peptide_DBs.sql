/****** Object:  View [dbo].[V_MTS_Peptide_DBs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_MTS_Peptide_DBs]
AS
SELECT P.Peptide_DB_ID,
       P.Peptide_DB_Name,
       S.Server_Name,
       P.State_ID,
       DBStates.Name AS State,
       P.Last_Affected,
       P.[Description],
       P.Organism,
       P.DB_Schema_Version,
       P.Comment,
       P.Created,
       S.Active AS Server_Active
FROM dbo.T_MTS_Peptide_DBs AS P
     INNER JOIN MT_Main.dbo.T_MT_Database_State_Name AS DBStates
       ON P.State_ID = DBStates.ID
     INNER JOIN dbo.T_MTS_Servers AS S
       ON P.Server_ID = S.Server_ID


GO
