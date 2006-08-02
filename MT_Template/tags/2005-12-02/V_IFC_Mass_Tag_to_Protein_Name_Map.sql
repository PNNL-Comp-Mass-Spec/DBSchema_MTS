SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_IFC_Mass_Tag_to_Protein_Name_Map]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_IFC_Mass_Tag_to_Protein_Name_Map]
GO


CREATE VIEW dbo.V_IFC_Mass_Tag_to_Protein_Name_Map
AS
SELECT dbo.T_Mass_Tag_to_Protein_Map.Mass_Tag_ID, 
    dbo.T_Proteins.Protein_ID, dbo.T_Proteins.Reference
FROM dbo.T_Mass_Tag_to_Protein_Map INNER JOIN
    dbo.T_Proteins ON 
    dbo.T_Mass_Tag_to_Protein_Map.Ref_ID = dbo.T_Proteins.Ref_ID


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

