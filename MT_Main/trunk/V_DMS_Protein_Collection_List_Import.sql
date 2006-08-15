/****** Object:  View [dbo].[V_DMS_Protein_Collection_List_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_DMS_Protein_Collection_List_Import
AS
SELECT *
FROM GIGASAX.Protein_Sequences.dbo.V_Protein_Collection_List_Export
     V_Protein_Collection_List_Export_1


GO
