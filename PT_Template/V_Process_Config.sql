/****** Object:  View [dbo].[V_Process_Config] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_Process_Config
AS
SELECT TOP 100 PERCENT Name, Value
FROM dbo.T_Process_Config
ORDER BY Name


GO
GRANT VIEW DEFINITION ON [dbo].[V_Process_Config] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_Process_Config] TO [MTS_DB_Lite] AS [dbo]
GO
