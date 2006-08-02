SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_DMS_Mass_Correction_Factors]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_DMS_Mass_Correction_Factors]
GO

CREATE VIEW dbo.V_DMS_Mass_Correction_Factors
AS
SELECT TOP 100 PERCENT t1.*
FROM GIGASAX.DMS5.dbo.T_Mass_Correction_Factors t1
ORDER BY Monoisotopic_Mass_Correction

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

