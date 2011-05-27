/****** Object:  View [dbo].[V_DMS_Enzymes] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Enzymes]
AS
SELECT Enzyme_ID,
       Enzyme_Name,
       Description,
       Protein_Collection_Name
FROM dbo.T_DMS_Enzymes_Cached


GO
