/****** Object:  View [dbo].[V_Import_Organism_DB_File_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_Import_Organism_DB_File_List
AS
SELECT Value
FROM dbo.T_Process_Config
WHERE (Name = 'Organism_DB_File_Name')


GO
GRANT VIEW DEFINITION ON [dbo].[V_Import_Organism_DB_File_List] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_Import_Organism_DB_File_List] TO [MTS_DB_Lite] AS [dbo]
GO
