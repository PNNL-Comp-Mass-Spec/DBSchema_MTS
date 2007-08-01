SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Sequence_Counts_By_Organism_File]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Sequence_Counts_By_Organism_File]
GO

CREATE VIEW dbo.V_Sequence_Counts_By_Organism_File
AS
SELECT TOP 100 PERCENT dbo.V_DMS_Organism_DB_File_Import.Organism,
     dbo.V_DMS_Organism_DB_File_Import.FileName, 
    COUNT(dbo.T_Seq_Map.Seq_ID) AS Sequence_Count
FROM dbo.T_Seq_Map INNER JOIN
    dbo.V_DMS_Organism_DB_File_Import ON 
    dbo.T_Seq_Map.Map_ID = dbo.V_DMS_Organism_DB_File_Import.ID
GROUP BY dbo.V_DMS_Organism_DB_File_Import.Organism, 
    dbo.V_DMS_Organism_DB_File_Import.FileName
ORDER BY dbo.V_DMS_Organism_DB_File_Import.Organism, 
    dbo.V_DMS_Organism_DB_File_Import.FileName

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

