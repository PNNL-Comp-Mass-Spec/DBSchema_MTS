/****** Object:  View [dbo].[V_Mass_Tag_Conformers_Predicted] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW V_Mass_Tag_Conformers_Predicted
AS
SELECT MTC.Mass_Tag_ID,
       MTC.Charge,
       MTC.Avg_Obs_NET AS Avg_Obs_NET_Cached,
       MTC.Predicted_Drift_Time,
       MTC.Update_Required,
       MT.Peptide,
       MT.Monoisotopic_Mass,
       MT.Mod_Count,
       MT.Mod_Description,
       MTN.Avg_GANET AS Avg_Obs_NET_Actual,
       MTN.Cnt_GANET AS Avg_Obs_NET_Count,
       MT.Cleavage_State_Max,
       MT.PeptideEx
FROM T_Mass_Tag_Conformers_Predicted MTC
     INNER JOIN T_Mass_Tags MT
       ON MTC.Mass_Tag_ID = MT.Mass_Tag_ID
     INNER JOIN T_Mass_Tags_NET MTN
       ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID

GO
