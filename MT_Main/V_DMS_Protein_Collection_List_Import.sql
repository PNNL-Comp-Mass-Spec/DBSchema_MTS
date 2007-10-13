/****** Object:  View [dbo].[V_DMS_Protein_Collection_List_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE VIEW [dbo].[V_DMS_Protein_Collection_List_Import]
AS
SELECT PCL.*
FROM ProteinSeqs.Protein_Sequences.dbo.V_Protein_Collection_List_Export PCL

GO
