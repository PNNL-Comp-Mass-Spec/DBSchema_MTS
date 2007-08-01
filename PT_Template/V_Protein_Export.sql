/****** Object:  View [dbo].[V_Protein_Export] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_Protein_Export
AS
SELECT dbo.T_Proteins.Ref_ID, dbo.T_Proteins.Reference, 
    dbo.T_Peptide_to_Protein_Map.Cleavage_State, 
    dbo.T_Sequence.Seq_ID, dbo.T_Peptides.Peptide_ID, 
    dbo.T_Peptides.Analysis_ID, 
    dbo.T_Peptide_to_Protein_Map.Terminus_State
FROM dbo.T_Proteins INNER JOIN
    dbo.T_Peptide_to_Protein_Map ON 
    dbo.T_Proteins.Ref_ID = dbo.T_Peptide_to_Protein_Map.Ref_ID INNER
     JOIN
    dbo.T_Peptides ON 
    dbo.T_Peptide_to_Protein_Map.Peptide_ID = dbo.T_Peptides.Peptide_ID
     INNER JOIN
    dbo.T_Sequence ON 
    dbo.T_Peptides.Seq_ID = dbo.T_Sequence.Seq_ID


GO