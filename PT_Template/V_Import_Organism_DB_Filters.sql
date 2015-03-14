/****** Object:  View [dbo].[V_Import_Organism_DB_Filters] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_Import_Organism_DB_Filters
AS
SELECT *
FROM dbo.T_Process_Config
WHERE (Name IN ('Organism_DB_File_Name', 
    'Protein_Collection_Filter', 'Seq_Direction_Filter', 
    'Protein_Collection_and_Protein_Options_Combo'))


GO
GRANT VIEW DEFINITION ON [dbo].[V_Import_Organism_DB_Filters] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_Import_Organism_DB_Filters] TO [MTS_DB_Lite] AS [dbo]
GO
