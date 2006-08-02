SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Peptide_Export]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Peptide_Export]
GO


CREATE VIEW dbo.V_Peptide_Export
AS
SELECT dbo.T_Peptides.Analysis_ID, 
    dbo.T_Peptides.Scan_Number, 
    dbo.T_Peptides.Number_Of_Scans, 
    dbo.T_Peptides.Charge_State, dbo.T_Peptides.MH, 
    dbo.T_Sequence.Monoisotopic_Mass, 
    dbo.T_Peptides.GANET_Obs, 
    dbo.T_Sequence.GANET_Predicted, 
    dbo.T_Peptides.Scan_Time_Peak_Apex, 
    dbo.T_Peptides.Multiple_ORF, dbo.T_Peptides.Peptide, 
    dbo.T_Sequence.Clean_Sequence, 
    dbo.T_Sequence.Mod_Count, 
    dbo.T_Sequence.Mod_Description, dbo.T_Peptides.Seq_ID, 
    dbo.T_Peptides.Peptide_ID, 
    dbo.T_Peptide_Filter_Flags.Filter_ID, 
    dbo.T_Peptides.Peak_Area, 
    dbo.T_Peptides.Peak_SN_Ratio
FROM dbo.T_Peptides INNER JOIN
    dbo.T_Sequence ON 
    dbo.T_Peptides.Seq_ID = dbo.T_Sequence.Seq_ID LEFT OUTER
     JOIN
    dbo.T_Peptide_Filter_Flags ON 
    dbo.T_Peptides.Peptide_ID = dbo.T_Peptide_Filter_Flags.Peptide_ID


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

