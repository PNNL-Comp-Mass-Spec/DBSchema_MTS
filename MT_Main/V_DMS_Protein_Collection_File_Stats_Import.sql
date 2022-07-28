/****** Object:  View [dbo].[V_DMS_Protein_Collection_File_Stats_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Protein_Collection_File_Stats_Import]
AS
SELECT AOF.Archived_File_ID,
        AOF.File_Size_Bytes,
        AOF.Protein_Collection_Count,
        AOF.Protein_Count,
        AOF.Residue_Count,
        CONVERT(varchar(500), AOF.Archived_File_Name) AS Archived_File_Name
FROM S_V_Archived_Output_File_Stats AOF


GO
