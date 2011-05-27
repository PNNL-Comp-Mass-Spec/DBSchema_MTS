/****** Object:  View [dbo].[V_DMS_Residues_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Residues_Import]
AS
SELECT t1.Residue_ID,
       t1.Residue_Symbol,
       t1.Description,
       t1.Average_Mass,
       t1.Monoisotopic_Mass,
       t1.Num_C,
       t1.Num_H,
       t1.Num_N,
       t1.Num_O,
       t1.Num_S,
       t1.Empirical_Formula
FROM GIGASAX.DMS5.dbo.T_Residues t1


GO
