/****** Object:  View [dbo].[V_Analysis_Job_to_Peptide_DB_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE VIEW V_Analysis_Job_to_Peptide_DB_Map
AS
SELECT TOP 100 PERCENT AJPDM.Job, AJPDM.ResultType, 
    MIN(PTDB.PDB_Name) AS DB_Name_First, 
    MAX(PTDB.PDB_Name) AS DB_Name_Last, 
    COUNT(AJPDM.PDB_ID) AS DB_Count, 
	MIN(AJPDM.Process_State) AS Process_State_Min, 
	MAX(AJPDM.Process_State) AS Process_State_Max, 
    MAX(AJPDM.Last_Affected) AS Last_Affected
FROM dbo.T_Analysis_Job_to_Peptide_DB_Map AJPDM INNER JOIN
    dbo.T_Peptide_Database_List PTDB ON 
    AJPDM.PDB_ID = PTDB.PDB_ID
GROUP BY AJPDM.Job, AJPDM.ResultType
ORDER BY AJPDM.Job

GO
