SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Active_MTS_Servers]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Active_MTS_Servers]
GO

CREATE VIEW dbo.V_Active_MTS_Servers
AS
SELECT TOP 100 PERCENT Server_ID, Server_Name
FROM dbo.T_MTS_Servers
WHERE (Active = 1)
ORDER BY Server_ID

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

