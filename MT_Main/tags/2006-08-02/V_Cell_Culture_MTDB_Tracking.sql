SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Cell_Culture_MTDB_Tracking]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Cell_Culture_MTDB_Tracking]
GO

CREATE VIEW dbo.V_Cell_Culture_MTDB_Tracking
AS
SELECT     dbo.T_Cell_Culture_MTDB_Tracking.MTDatabase, dbo.T_Cell_Culture_MTDB_Tracking.Experiments, dbo.T_Cell_Culture_MTDB_Tracking.Datasets, 
                      dbo.T_Cell_Culture_MTDB_Tracking.Jobs, dbo.T_MT_Database_List.MTL_Description AS Description, 
                      dbo.T_MT_Database_List.MTL_Campaign AS Campaign, dbo.T_MT_Database_State_Name.Name AS State, 
                      dbo.T_MT_Database_List.MTL_Created AS Created, dbo.T_Cell_Culture_MTDB_Tracking.CellCulture
FROM         dbo.T_Cell_Culture_MTDB_Tracking INNER JOIN
                      dbo.T_MT_Database_List ON dbo.T_Cell_Culture_MTDB_Tracking.MTDatabaseID = dbo.T_MT_Database_List.MTL_ID INNER JOIN
                      dbo.T_MT_Database_State_Name ON dbo.T_MT_Database_List.MTL_State = dbo.T_MT_Database_State_Name.ID

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

