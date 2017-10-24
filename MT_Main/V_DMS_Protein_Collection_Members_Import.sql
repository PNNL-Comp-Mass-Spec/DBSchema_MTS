/****** Object:  View [dbo].[V_DMS_Protein_Collection_Members_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE VIEW [dbo].[V_DMS_Protein_Collection_Members_Import]
AS
SELECT Protein_Collection_ID,
       Protein_Name,
       Description,
       Protein_Sequence,
       Monoisotopic_Mass,
       Average_Mass,
       Residue_Count,
       Molecular_Formula,
       Protein_ID,
       Reference_ID,
       SHA1_Hash,
       Member_ID,
       Sorting_Index
FROM S_V_Protein_Collection_Members


GO
