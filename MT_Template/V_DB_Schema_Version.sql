/****** Object:  View [dbo].[V_DB_Schema_Version] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_DB_Schema_Version
AS
SELECT ISNULL(Value, 2) AS DB_Schema_Version
FROM dbo.T_Process_Config
WHERE (Name = 'DB_Schema_Version')


GO
GRANT VIEW DEFINITION ON [dbo].[V_DB_Schema_Version] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_DB_Schema_Version] TO [MTS_DB_Lite] AS [dbo]
GO
