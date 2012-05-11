/****** Object:  View [dbo].[V_DMS_Filter_Set_Report] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_DMS_Filter_Set_Report
AS
SELECT FSO.Filter_Type_Name,
       FSO.Filter_Set_ID,
       FSO.Filter_Set_Name,
       FSO.Filter_Set_Description,
       PR.Filter_Criteria_Group_ID,
       PR.[1]  AS Spectrum_Count,
       PR.[2]  AS Charge,
       PR.[3]  AS High_Normalized_Score,
       PR.[4]  AS Cleavage_State,
       PR.[13] AS Terminus_State,
       PR.[5]  AS Peptide_Length,
       PR.[6]  AS Mass,
       PR.[7]  AS DelCn,
       PR.[8]  AS DelCn2,
       PR.[9]  AS Discriminant_Score,
       PR.[10] AS NET_Difference_Absolute,
       PR.[11] AS Discriminant_Initial_Filter,
       PR.[12] AS Protein_Count,
       PR.[14] AS XTandem_Hyperscore,
       PR.[15] AS XTandem_LogEValue,
       PR.[16] AS Peptide_Prophet_Probability,
       PR.[17] AS RankScore,
       PR.[18] AS Inspect_MQScore,
       PR.[19] AS Inspect_TotalPRMScore,
       PR.[20] AS Inspect_FScore,
       PR.[21] AS Inspect_PValue,
       PR.[22] AS MSGF_SpecProb,
       PR.[23] AS MSGFDB_SpecProb,
       PR.[24] AS MSGFDB_PValue,
       PR.[25] AS MSGFDB_FDR       
FROM ( SELECT FSD.Filter_Set_ID,
              FSD.Filter_Criteria_Group_ID,
              FSD.Criterion_ID,
              FSD.Criterion_Comparison + CONVERT(varchar(18), FSD.Criterion_Value) AS Criterion
       FROM dbo.T_DMS_Filter_Set_Details_Cached FSD ) AS DataQ
     PIVOT ( MAX(Criterion)
             FOR Criterion_id
             IN ( [1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12], [13], [14], [15], [16], [17], [18], [19], [20], [21], [22], [23], [24], [25] ) 
     ) AS PR
     INNER JOIN dbo.T_DMS_Filter_Set_Overview_Cached FSO
       ON PR.Filter_Set_ID = FSO.Filter_Set_ID

GO
