/****** Object:  View [dbo].[V_ToolVersionInfo_Append] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_ToolVersionInfo_Append] AS
SELECT Data
FROM T_ToolVersionInfoContents

GO
GRANT VIEW DEFINITION ON [dbo].[V_ToolVersionInfo_Append] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_ToolVersionInfo_Append] TO [MTS_DB_Lite] AS [dbo]
GO
