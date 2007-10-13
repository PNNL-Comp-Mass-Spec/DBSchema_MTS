/****** Object:  View [dbo].[V_DMS_Protein_Collection_Members_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE VIEW [dbo].[V_DMS_Protein_Collection_Members_Import]
AS
SELECT PCME.*
FROM ProteinSeqs.Protein_Sequences.dbo.V_Protein_Collection_Members_Export PCME

GO
