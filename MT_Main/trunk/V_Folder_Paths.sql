SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Folder_Paths]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Folder_Paths]
GO

CREATE VIEW dbo.V_Folder_Paths
AS
SELECT     [Function], Client_Path, Server_Path
FROM         dbo.T_Folder_Paths

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

