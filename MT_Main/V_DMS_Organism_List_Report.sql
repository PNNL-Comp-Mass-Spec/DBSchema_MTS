/****** Object:  View [dbo].[V_DMS_Organism_List_Report] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[V_DMS_Organism_List_Report]
AS
SELECT ID,
       Name,
       Genus,
       Species,
       Strain,
       Description,
       Short_Name,
       Domain,
       Kingdom,
       Phylum,
       Class,
       [Order],
       Family,
       Created,
       Active
FROM S_V_Organism_List_Report


GO
