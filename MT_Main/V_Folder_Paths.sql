/****** Object:  View [dbo].[V_Folder_Paths] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Folder_Paths
AS
SELECT     [Function], Client_Path, Server_Path
FROM         dbo.T_Folder_Paths

GO
