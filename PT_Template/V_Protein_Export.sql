/****** Object:  View [dbo].[V_Protein_Export] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_Protein_Export
AS
SELECT Prot.Ref_ID,
       Prot.Reference,
       PPM.Cleavage_State,
       S.Seq_ID,
       Pep.Peptide_ID,
       Pep.Job,
       PPM.Terminus_State
FROM T_Proteins Prot
     INNER JOIN T_Peptide_to_Protein_Map PPM
       ON Prot.Ref_ID = PPM.Ref_ID
     INNER JOIN T_Peptides Pep
       ON PPM.Peptide_ID = Pep.Peptide_ID
     INNER JOIN T_Sequence S
       ON Pep.Seq_ID = S.Seq_ID

GO
