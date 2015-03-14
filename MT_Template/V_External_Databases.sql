/****** Object:  View [dbo].[V_External_Databases] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create VIEW dbo.V_External_Databases
AS
SELECT M.Protein_DB_Name, N.Peptide_DB_Name
FROM (SELECT Name, Value AS Protein_DB_Name
      FROM dbo.T_Process_Config
      WHERE (Name = 'Protein_DB_Name')) M CROSS JOIN
        (SELECT Name, Value AS Peptide_DB_Name
      FROM dbo.T_Process_Config
      WHERE (Name = 'Peptide_DB_Name')) N

GO
GRANT VIEW DEFINITION ON [dbo].[V_External_Databases] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_External_Databases] TO [MTS_DB_Lite] AS [dbo]
GO
