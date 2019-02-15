/****** Object:  View [dbo].[V_DMS_Residues_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Residues_Import]
AS
SELECT Residue_ID,
       Residue_Symbol,
       Description,
       Average_Mass,
       Monoisotopic_Mass,
       Num_C,
       Num_H,
       Num_N,
       Num_O,
       Num_S,
       Empirical_Formula,
       Amino_Acid_Name
FROM S_V_Residues


GO
