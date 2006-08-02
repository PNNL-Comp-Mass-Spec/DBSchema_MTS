SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Analysis_Job_to_Peptide_DB_Map]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Analysis_Job_to_Peptide_DB_Map]
GO

CREATE VIEW dbo.V_Analysis_Job_to_Peptide_DB_Map
AS
SELECT TOP 100 PERCENT AJPDM.Job, AJPDM.ResultType, 
    MIN(PTDB.PDB_Name) AS PDB_Name_First, 
    MAX(PTDB.PDB_Name) AS PDB_Name_Last, 
    COUNT(AJPDM.PDB_ID) AS PDB_Count
FROM dbo.T_Analysis_Job_to_Peptide_DB_Map AJPDM INNER JOIN
    dbo.T_Peptide_Database_List PTDB ON 
    AJPDM.PDB_ID = PTDB.PDB_ID
GROUP BY AJPDM.Job, AJPDM.ResultType
ORDER BY AJPDM.Job

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

