/****** Object:  View [dbo].[V_IFC_Proteins] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_IFC_Proteins
AS
SELECT Ref_ID, Reference, Description, Protein_Sequence, 
    Protein_Residue_Count, Monoisotopic_Mass, Protein_DB_ID, 
    External_Reference_ID, External_Protein_ID
FROM dbo.T_Proteins


GO
