SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Sequences_With_Filter_Flags_Set]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Sequences_With_Filter_Flags_Set]
GO


CREATE VIEW dbo.V_Sequences_With_Filter_Flags_Set
AS
SELECT dbo.T_Sequence.Seq_ID, 
    dbo.T_Sequence.Clean_Sequence, 
    dbo.T_Sequence.Monoisotopic_Mass, 
    dbo.T_Sequence.Mod_Count, 
    dbo.T_Sequence.Mod_Description
FROM dbo.T_Sequence INNER JOIN
        (SELECT DISTINCT T_Peptides.Seq_ID AS Seq_ID
      FROM T_Peptides INNER JOIN
           T_Peptide_Filter_Flags ON 
           T_Peptides.Peptide_ID = T_Peptide_Filter_Flags.Peptide_ID)
     T ON dbo.T_Sequence.Seq_ID = T.Seq_ID


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

