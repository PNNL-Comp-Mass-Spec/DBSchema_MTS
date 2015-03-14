/****** Object:  View [dbo].[V_Config_Info] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_Config_Info
AS
SELECT TOP 100 PERCENT PC.Process_Config_ID, PC.Name, 
    PC.Value, PCP.[Function], PCP.Description, 
    PCP.Min_Occurrences, PCP.Max_Occurrences
FROM dbo.T_Process_Config PC INNER JOIN
    dbo.T_Process_Config_Parameters PCP ON 
    PC.Name = PCP.Name
ORDER BY PCP.[Function], PC.Name


GO
GRANT VIEW DEFINITION ON [dbo].[V_Config_Info] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_Config_Info] TO [MTS_DB_Lite] AS [dbo]
GO
