SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_DB_Schema_Version]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_DB_Schema_Version]
GO


CREATE VIEW dbo.V_DB_Schema_Version
AS
SELECT ISNULL(Value, 2) AS DB_Schema_Version
FROM dbo.T_Process_Config
WHERE (Name = 'DB_Schema_Version')


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

