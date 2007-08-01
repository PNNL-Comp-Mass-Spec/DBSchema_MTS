/****** Object:  View [dbo].[V_DMS_Mass_Correction_Factors] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_DMS_Mass_Correction_Factors
AS
SELECT TOP 100 PERCENT t1.*
FROM GIGASAX.DMS5.dbo.T_Mass_Correction_Factors t1
ORDER BY Monoisotopic_Mass_Correction

GO
