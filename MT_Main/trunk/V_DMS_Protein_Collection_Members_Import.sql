/****** Object:  View [dbo].[V_DMS_Protein_Collection_Members_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create VIEW V_DMS_Protein_Collection_Members_Import
AS
SELECT *
FROM GIGASAX.Protein_Sequences.dbo.V_Protein_Collection_Members_Export
     V_Protein_Collection_Members_Export_1

GO
