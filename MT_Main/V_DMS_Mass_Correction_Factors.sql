/****** Object:  View [dbo].[V_DMS_Mass_Correction_Factors] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Mass_Correction_Factors]
AS
SELECT Mass_Correction_ID,
       Mass_Correction_Tag,
       Description,
       Monoisotopic_Mass_Correction,
       Average_Mass_Correction,
       Affected_Atom,
       Original_Source,
       Original_Source_Name,
       Alternative_Name,
       Empirical_Formula
FROM dbo.T_DMS_Mass_Correction_Factors_Cached


GO
