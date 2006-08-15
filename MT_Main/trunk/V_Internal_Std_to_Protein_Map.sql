/****** Object:  View [dbo].[V_Internal_Std_to_Protein_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Internal_Std_to_Protein_Map
AS
SELECT dbo.T_Internal_Std_Proteins.Internal_Std_Protein_ID, 
    dbo.T_Internal_Std_Proteins.Protein_Name, 
    dbo.T_Internal_Std_Proteins.Protein_ID, 
    dbo.T_Internal_Std_Proteins.Protein_Sequence, 
    dbo.T_Internal_Std_Proteins.Monoisotopic_Mass, 
    dbo.T_Internal_Std_Proteins.Protein_DB_ID, 
    dbo.T_Internal_Std_to_Protein_Map.Seq_ID
FROM dbo.T_Internal_Std_Proteins INNER JOIN
    dbo.T_Internal_Std_to_Protein_Map ON 
    dbo.T_Internal_Std_Proteins.Internal_Std_Protein_ID = dbo.T_Internal_Std_to_Protein_Map.Internal_Std_Protein_ID

GO
