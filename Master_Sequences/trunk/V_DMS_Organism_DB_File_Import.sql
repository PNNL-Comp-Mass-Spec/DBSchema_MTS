/****** Object:  View [dbo].[V_DMS_Organism_DB_File_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_DMS_Organism_DB_File_Import
AS
SELECT t1.*
FROM GIGASAX.DMS5.dbo.V_Organism_DB_File_Export t1

GO
