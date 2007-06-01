/****** Object:  View [dbo].[V_IFC_Mass_Tag_to_Protein_Name_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_IFC_Mass_Tag_to_Protein_Name_Map
AS
SELECT MTPM.Mass_Tag_ID, Prot.Ref_ID AS Internal_Ref_ID, 
    Prot.Protein_DB_ID, Prot.External_Reference_ID, 
    Prot.External_Protein_ID, Prot.Reference,
    Prot.Description, Prot.Protein_Residue_Count, 
    Prot.Monoisotopic_Mass
FROM dbo.T_Mass_Tag_to_Protein_Map MTPM INNER JOIN
    dbo.T_Proteins Prot ON MTPM.Ref_ID = Prot.Ref_ID


GO
