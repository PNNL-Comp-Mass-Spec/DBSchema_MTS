SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Mass_Tag_to_Protein_Map_Full_Sequence]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Mass_Tag_to_Protein_Map_Full_Sequence]
GO


CREATE VIEW dbo.V_Mass_Tag_to_Protein_Map_Full_Sequence
AS
SELECT TOP 100 PERCENT Mass_Tag_ID, Ref_ID, Cleavage_state, 
    CASE WHEN prefix = '' THEN '-' ELSE prefix END + '.' + Peptide +
     '.' + CASE WHEN suffix = '' THEN '-' ELSE suffix END AS Peptide_Sequence
FROM (SELECT MTPM.Mass_Tag_ID, MTPM.Ref_ID, 
          Cleavage_state, SUBSTRING(Pro.Protein_Sequence, 
          MTPM.Residue_Start - 1, 1) AS Prefix, 
          T_Mass_Tags.Peptide, 
          SUBSTRING(Pro.Protein_Sequence, 
          MTPM.Residue_End + 1, 1) AS Suffix
      FROM T_Mass_Tag_to_Protein_Map MTPM INNER JOIN
          T_Proteins Pro ON 
          MTPM.Ref_ID = Pro.Ref_ID INNER JOIN
          T_Mass_Tags ON 
          MTPM.Mass_Tag_ID = T_Mass_Tags.Mass_Tag_ID) 
    LookupQ
ORDER BY Mass_Tag_ID, Ref_ID


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

