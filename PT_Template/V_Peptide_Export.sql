/****** Object:  View [dbo].[V_Peptide_Export] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[V_Peptide_Export]
AS
SELECT Pep.Job,
       Pep.Scan_Number,
       Pep.Number_Of_Scans,
       Pep.Charge_State,
       Pep.MH,
       S.Monoisotopic_Mass,
       Pep.GANET_Obs,
       S.GANET_Predicted,
       Pep.Scan_Time_Peak_Apex,
       Pep.Multiple_ORF,
       Pep.Peptide,
       S.Clean_Sequence,
       S.Mod_Count,
       S.Mod_Description,
       Pep.Seq_ID,
       Pep.Peptide_ID,
       PFF.Filter_ID,
       Pep.Peak_Area,
       Pep.Peak_SN_Ratio,
       Pep.DelM_PPM,
       Pep.RankHit
FROM T_Peptides Pep
     INNER JOIN T_Sequence S
       ON Pep.Seq_ID = S.Seq_ID
     LEFT OUTER JOIN T_Peptide_Filter_Flags PFF
       ON Pep.Peptide_ID = PFF.Peptide_ID


GO
GRANT VIEW DEFINITION ON [dbo].[V_Peptide_Export] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_Peptide_Export] TO [MTS_DB_Lite] AS [dbo]
GO
