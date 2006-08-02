SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Cell_Culture_MTDB_Summary]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Cell_Culture_MTDB_Summary]
GO



CREATE VIEW V_Cell_Culture_MTDB_Summary
AS
SELECT     T_Cell_Culture_MTDB_Tracking.CellCulture, COUNT(T_Cell_Culture_MTDB_Tracking.MTDatabase) AS MTDatabases, 
                      T_MT_Database_List.MTL_Campaign AS Campaign
FROM         T_Cell_Culture_MTDB_Tracking INNER JOIN
                      T_MT_Database_List ON T_Cell_Culture_MTDB_Tracking.MTDatabase = T_MT_Database_List.MTL_Name
GROUP BY T_Cell_Culture_MTDB_Tracking.CellCulture, T_MT_Database_List.MTL_Campaign

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

