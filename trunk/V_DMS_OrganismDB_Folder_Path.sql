/****** Object:  View [dbo].[V_DMS_OrganismDB_Folder_Path] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_DMS_OrganismDB_Folder_Path
AS
SELECT t1.*
FROM (SELECT OG_name, OG_organismDBPath
      FROM gigasax.dms5.dbo.T_Organisms) t1

GO
