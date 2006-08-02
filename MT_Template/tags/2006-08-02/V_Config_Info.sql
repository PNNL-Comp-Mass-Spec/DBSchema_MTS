SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Config_Info]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Config_Info]
GO

create VIEW dbo.V_Config_Info
AS
SELECT TOP 100 PERCENT PC.Process_Config_ID, PC.Name, 
    PC.Value, PCP.[Function], PCP.Description, 
    PCP.Min_Occurrences, PCP.Max_Occurrences
FROM dbo.T_Process_Config PC INNER JOIN
    dbo.T_Process_Config_Parameters PCP ON 
    PC.Name = PCP.Name
ORDER BY PCP.[Function], PC.Name

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

