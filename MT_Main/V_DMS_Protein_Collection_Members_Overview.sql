/****** Object:  View [dbo].[V_DMS_Protein_Collection_Members_Overview] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_DMS_Protein_Collection_Members_Overview
AS
SELECT *
FROM GIGASAX.Protein_Sequences.dbo.V_Protein_Collection_Members_Overview_Export
     V_Protein_Collection_Members_Overview_Export_1


GO
