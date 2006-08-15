/****** Object:  View [dbo].[V_Process_State_Summary] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_Process_State_Summary
AS
SELECT TOP 100 PERCENT COUNT(dbo.T_Analysis_Description.Job)
     AS [Job Count], dbo.T_Process_State.Name AS State, 
    dbo.T_Process_State.ID AS State_ID
FROM dbo.T_Analysis_Description INNER JOIN
    dbo.T_Process_State ON 
    dbo.T_Analysis_Description.Process_State = dbo.T_Process_State.ID
GROUP BY dbo.T_Process_State.Name, 
    dbo.T_Process_State.ID
ORDER BY dbo.T_Process_State.ID


GO
