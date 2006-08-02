SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_DMS_Mass_Correction_Factors]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_DMS_Mass_Correction_Factors]
GO

CREATE VIEW dbo.V_DMS_Mass_Correction_Factors
AS
SELECT MT_Main.dbo.V_DMS_Mass_Correction_Factors.*
FROM MT_Main.dbo.V_DMS_Mass_Correction_Factors

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

