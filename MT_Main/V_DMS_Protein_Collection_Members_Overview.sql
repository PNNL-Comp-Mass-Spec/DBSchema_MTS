/****** Object:  View [dbo].[V_DMS_Protein_Collection_Members_Overview] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE VIEW [dbo].[V_DMS_Protein_Collection_Members_Overview]
AS
SELECT PCMO.*
FROM ProteinSeqs.Protein_Sequences.dbo.V_Protein_Collection_Members_Overview_Export PCMO

GO
