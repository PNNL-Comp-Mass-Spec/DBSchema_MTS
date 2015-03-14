/****** Object:  View [dbo].[V_Sequest_vs_Inspect] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_Sequest_vs_Inspect
AS
SELECT SequestQ.Dataset_ID,
       SequestQ.Scan_Number,
       SequestQ.Charge_State,
       SequestQ.Mass_Tag_ID,
       SequestQ.XCorr,
       SequestQ.DeltaCn,
       SequestQ.DeltaCn2,
       InspectQ.Inspect_Normalized_Score,
       InspectQ.MQScore,
       InspectQ.TotalPRMScore,
       InspectQ.DeltaNormTotalPRMScore,
       InspectQ.FScore,
       InspectQ.PValue
FROM ( SELECT TAD.Dataset_ID,
              P.Scan_Number,
              P.Charge_State,
              P.Mass_Tag_ID,
              SS.XCorr,
              SS.DeltaCn,
              SS.DeltaCn2
       FROM T_Analysis_Description TAD
            INNER JOIN T_Peptides P
              ON TAD.Job = P.Job
            INNER JOIN T_Score_Sequest SS
              ON P.Peptide_ID = SS.Peptide_ID
       WHERE (TAD.ResultType = 'Peptide_Hit') ) SequestQ
     INNER JOIN ( SELECT TAD.Dataset_ID,
                         P.Scan_Number,
                         P.Charge_State,
                         P.Mass_Tag_ID,
                         I.MQScore,
                         I.TotalPRMScore,
                         I.FScore,
                         I.DeltaNormTotalPRMScore,
                         I.PValue,
                         I.Normalized_Score AS Inspect_Normalized_Score
                  FROM T_Analysis_Description TAD
                       INNER JOIN T_Peptides P
                         ON TAD.Job = P.Job
                       INNER JOIN T_Score_Inspect I
                         ON P.Peptide_ID = I.Peptide_ID
                  WHERE (TAD.ResultType = 'IN_Peptide_Hit') ) InspectQ
       ON SequestQ.Charge_State = InspectQ.Charge_State AND
          SequestQ.Dataset_ID = InspectQ.Dataset_ID AND
          SequestQ.Scan_Number = InspectQ.Scan_Number AND
          SequestQ.Mass_Tag_ID = InspectQ.Mass_Tag_ID

GO
GRANT VIEW DEFINITION ON [dbo].[V_Sequest_vs_Inspect] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_Sequest_vs_Inspect] TO [MTS_DB_Lite] AS [dbo]
GO
