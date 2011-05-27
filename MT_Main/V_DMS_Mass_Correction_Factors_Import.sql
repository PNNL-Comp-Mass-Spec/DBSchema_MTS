/****** Object:  View [dbo].[V_DMS_Mass_Correction_Factors_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Mass_Correction_Factors_Import]
AS
SELECT t1.Mass_Correction_ID,
       t1.Mass_Correction_Tag,
       t1.Description,
       t1.Monoisotopic_Mass_Correction,
       t1.Average_Mass_Correction,
       t1.Affected_Atom,
       t1.Original_Source,
       t1.Original_Source_Name,
       t1.Alternative_Name,
       t1.Empirical_Formula
FROM GIGASAX.DMS5.dbo.T_Mass_Correction_Factors t1


GO
