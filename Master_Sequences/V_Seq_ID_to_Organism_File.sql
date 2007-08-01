/****** Object:  View [dbo].[V_Seq_ID_to_Organism_File] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Seq_ID_to_Organism_File
AS
SELECT dbo.T_Seq_Map.Seq_ID, 
    dbo.V_DMS_Organism_DB_File_Import.Organism, 
    dbo.V_DMS_Organism_DB_File_Import.FileName, 
    dbo.V_DMS_Organism_DB_File_Import.Description
FROM dbo.T_Seq_Map INNER JOIN
    dbo.V_DMS_Organism_DB_File_Import ON 
    dbo.T_Seq_Map.Map_ID = dbo.V_DMS_Organism_DB_File_Import.ID

GO
