/****** Object:  View [dbo].[V_PMT_Quality_Score_Report] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_PMT_Quality_Score_Report
AS
SELECT PMTQS.*,
       FSO.Filter_Set_ID,
       FSO.Filter_Set_Name,
       FSO.Filter_Set_Description,
       FSO.Experiment_Filter,
       FSO.Instrument_Class_Filter
FROM ( SELECT QualityScores.PMT_Quality_Score,
              SUM(LookupQ.MTCount) AS MT_Count_Passing_QS
       FROM ( SELECT DISTINCT PMT_Quality_Score
              FROM T_Mass_Tags ) QualityScores
            INNER JOIN ( SELECT PMT_Quality_Score,
                                COUNT(*) AS MTCount
                         FROM T_Mass_Tags
                         GROUP BY PMT_Quality_Score ) LookupQ
              ON QualityScores.PMT_Quality_Score <= LookupQ.PMT_Quality_Score
       GROUP BY QualityScores.PMT_Quality_Score 
     ) PMTQS
     LEFT OUTER JOIN V_Filter_Set_Overview FSO
       ON PMTQS.PMT_Quality_Score = FSO.PMT_Quality_Score_Value


GO
GRANT VIEW DEFINITION ON [dbo].[V_PMT_Quality_Score_Report] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_PMT_Quality_Score_Report] TO [MTS_DB_Lite] AS [dbo]
GO
