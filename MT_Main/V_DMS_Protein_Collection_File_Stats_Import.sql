/****** Object:  View [dbo].[V_DMS_Protein_Collection_File_Stats_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_DMS_Protein_Collection_File_Stats_Import
AS
SELECT AOF.Archived_File_ID,
        AOF.Filesize,
        AOF.Protein_Collection_Count,
        AOF.Protein_Count,
        AOF.Residue_Count,
        CONVERT(varchar(500), AOF.Archived_File_Name) AS Archived_File_Name
FROM ProteinSeqs.Protein_Sequences.dbo.V_Archived_Output_File_Stats_Export AOF

GO
