/****** Object:  View [dbo].[V_Active_MTS_Servers] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Active_MTS_Servers
AS
SELECT TOP 100 PERCENT Server_ID, Server_Name
FROM dbo.T_MTS_Servers
WHERE (Active = 1)
ORDER BY Server_ID

GO
