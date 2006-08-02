SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_External_Databases]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_External_Databases]
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

