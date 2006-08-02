SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_MasterSeq_Sequence_IDs_with_Mods]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_MasterSeq_Sequence_IDs_with_Mods]
GO

CREATE VIEW dbo.V_MasterSeq_Sequence_IDs_with_Mods
AS
SELECT dbo.T_Sequence.Seq_ID, MD.Mass_Correction_Tag, 
    MD.Position
FROM dbo.T_Sequence INNER JOIN
    Albert.Master_Sequences.dbo.T_Mod_Descriptors MD ON 
    dbo.T_Sequence.Seq_ID = MD.Seq_ID

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

