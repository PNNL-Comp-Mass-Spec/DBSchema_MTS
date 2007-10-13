/****** Object:  View [dbo].[V_DMS_Protein_Collection_File_Stats_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE VIEW [dbo].[V_DMS_Protein_Collection_File_Stats_Import]
AS
SELECT AOF.*
FROM ProteinSeqs.Protein_Sequences.dbo.V_Archived_Output_File_Stats_Export AOF

GO
