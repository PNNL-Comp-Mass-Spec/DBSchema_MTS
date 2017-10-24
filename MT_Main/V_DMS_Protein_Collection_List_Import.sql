/****** Object:  View [dbo].[V_DMS_Protein_Collection_List_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[V_DMS_Protein_Collection_List_Import]
AS
SELECT Protein_Collection_ID,
       Name,
       Description,
       Collection_State,
       Collection_Type,
       Protein_Count,
       Residue_Count,
       Annotation_Naming_Authority,
       Annotation_Type,
       Organism_ID,
       Created,
       Last_Modified,
       Authentication_Hash,
       Collection_RowVersion
FROM S_V_Protein_Collection_List


GO
