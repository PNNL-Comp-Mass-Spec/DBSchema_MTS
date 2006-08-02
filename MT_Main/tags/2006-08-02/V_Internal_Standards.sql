SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Internal_Standards]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Internal_Standards]
GO

CREATE VIEW dbo.V_Internal_Standards
AS
SELECT Internal_Std_Mix_ID, Name, Description, Type
FROM dbo.T_Internal_Standards

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

