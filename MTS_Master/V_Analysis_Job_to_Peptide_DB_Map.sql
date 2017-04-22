/****** Object:  View [dbo].[V_Analysis_Job_to_Peptide_DB_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_Analysis_Job_to_Peptide_DB_Map]
AS
SELECT S.Server_Name, 
       AJPDM.Job, 
       AJPDM.ResultType, 
	   ISNULL(D.Peptide_DB_Name, '??') AS DB_Name, 
	   AJPDM.Last_Affected, 
	   CONVERT(varchar(12), AJPDM.Process_State) + ': ' + ISNULL(StateName.Name, '??') AS Process_State, 
	   AJPDM.Server_ID, 
	   AJPDM.Peptide_DB_ID
FROM dbo.T_Analysis_Job_to_Peptide_DB_Map AS AJPDM INNER JOIN
    dbo.T_MTS_Servers AS S ON 
    AJPDM.Server_ID = S.Server_ID LEFT OUTER JOIN
    dbo.T_Analysis_Job_Peptide_DB_State_Name AS StateName ON
     AJPDM.Process_State = StateName.ID LEFT OUTER JOIN
    dbo.T_MTS_Peptide_DBs AS D ON 
    AJPDM.Peptide_DB_ID = D.Peptide_DB_ID AND 
    AJPDM.Server_ID = D.Server_ID


GO
