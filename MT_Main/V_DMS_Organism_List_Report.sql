/****** Object:  View [dbo].[V_DMS_Organism_List_Report] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Organism_List_Report]
AS
SELECT  t1.ID,
        t1.Name,
        t1.Genus,
        t1.Species,
        t1.Strain,
        t1.Description,
        t1.Short_Name,
        t1.Domain,
        t1.Kingdom,
        t1.Phylum,
        t1.Class,
        t1.[Order],
        t1.Family,
        t1.Created,
        t1.Active
FROM GIGASAX.DMS5.dbo.V_Organism_List_Report t1


GO
