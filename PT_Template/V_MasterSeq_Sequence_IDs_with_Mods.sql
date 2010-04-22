/****** Object:  View [dbo].[V_MasterSeq_Sequence_IDs_with_Mods] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_MasterSeq_Sequence_IDs_with_Mods]
AS
SELECT S.Seq_ID,
       MD.Mass_Correction_Tag,
       MD.Position
FROM dbo.T_Sequence S
     INNER JOIN ProteinSeqs2.Master_Sequences.dbo.T_Mod_Descriptors AS MD
       ON S.Seq_ID = MD.Seq_ID


GO
