/****** Object:  View [dbo].[V_DMS_Enzymes_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Enzymes_Import]
AS
SELECT T1.Enzyme_ID,
       T1.Enzyme_Name,
       T1.Description,
       T1.P1,
       T1.P1_Exception,
       T1.P2,
       T1.P2_Exception,
       T1.Cleavage_Method,
       T1.Cleavage_Offset,
       T1.Sequest_Enzyme_Index,
       T1.Protein_Collection_Name
FROM GIGASAX.DMS5.dbo.T_Enzymes T1


GO
