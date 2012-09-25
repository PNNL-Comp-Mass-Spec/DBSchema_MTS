/****** Object:  View [dbo].[V_DMS_Protein_Collection_List_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_DMS_Protein_Collection_List_Import
AS
SELECT PCL.Protein_Collection_ID,
        PCL.Name,
        PCL.Description,
        PCL.Collection_State,
        PCL.Collection_Type,
        PCL.Protein_Count,
        PCL.Residue_Count,
        PCL.Annotation_Naming_Authority,
        PCL.Annotation_Type,
        PCL.Organism_ID,
        PCL.Created,
        PCL.Last_Modified,
        PCL.Authentication_Hash,
        PCL.Collection_RowVersion
FROM ProteinSeqs.Protein_Sequences.dbo.V_Protein_Collection_List_Export PCL

GO
