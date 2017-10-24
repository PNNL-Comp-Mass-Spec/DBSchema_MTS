/****** Object:  View [dbo].[V_DMS_Organisms_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[V_DMS_Organisms_Import]
AS
SELECT Organism_ID,
       Name,
       Description,
       Short_Name,
       Domain,
       Kingdom,
       Phylum,
       Class,
       [Order],
       Family,
       Genus,
       Species,
       Strain,
       DNA_Translation_Table_ID,
       Mito_DNA_Translation_Table_ID,
       Created,
       Active,
       OrganismDBPath,
       OG_RowVersion
FROM S_V_Organisms


GO
