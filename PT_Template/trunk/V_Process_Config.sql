SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Process_Config]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Process_Config]
GO


CREATE VIEW dbo.V_Process_Config
AS
SELECT TOP 100 PERCENT Name, Value
FROM dbo.T_Process_Config
ORDER BY Name


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

