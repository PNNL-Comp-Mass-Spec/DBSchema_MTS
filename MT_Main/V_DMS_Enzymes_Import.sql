/****** Object:  View [dbo].[V_DMS_Enzymes_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Enzymes_Import]
AS
SELECT Enzyme_ID,
       Enzyme_Name,
       Description,
       P1,
       P1_Exception,
       P2,
       P2_Exception,
       Cleavage_Method,
       Cleavage_Offset,
       Sequest_Enzyme_Index,
       Protein_Collection_Name
FROM S_V_Enzymes


GO
