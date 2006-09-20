/****** Object:  View [dbo].[V_PT_DBs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_PT_DBs
AS
SELECT TOP 100 PERCENT S.Server_Name,
    P.Peptide_DB_ID, 
    P.Peptide_DB_Name, 
    P.State_ID, 
    P.Last_Affected, 
    P.DB_Schema_Version
FROM dbo.T_MTS_Peptide_DBs P INNER JOIN
    dbo.T_MTS_Servers S ON P.Server_ID = S.Server_ID
WHERE (S.Active = 1) AND (P.State_ID < 15)


GO
