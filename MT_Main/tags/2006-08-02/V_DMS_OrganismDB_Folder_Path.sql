SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_DMS_OrganismDB_Folder_Path]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_DMS_OrganismDB_Folder_Path]
GO

CREATE VIEW dbo.V_DMS_OrganismDB_Folder_Path
AS
SELECT t1.*
FROM (SELECT OG_name, OG_organismDBPath
      FROM gigasax.dms5.dbo.T_Organisms) t1

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

