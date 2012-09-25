/****** Object:  View [dbo].[V_DMS_Organism_DB_File_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Organism_DB_File_Import]
AS
SELECT ID, FileName, Organism,
       Description, Active,
       NumProteins, NumResidues,
       Organism_ID, OrgFile_RowVersion
FROM GIGASAX.DMS5.dbo.V_Organism_DB_File_Export AS t1


GO
