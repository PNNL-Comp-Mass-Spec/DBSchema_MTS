/****** Object:  View [dbo].[V_PMT_Quality_Score_Report] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_PMT_Quality_Score_Report
AS
SELECT QualityScores.PMT_Quality_Score,
       SUM(LookupQ.MTCount) AS MT_Count_Passing_QS
FROM ( SELECT DISTINCT PMT_Quality_Score
       FROM t_mass_tags ) QualityScores
     INNER JOIN ( SELECT PMT_Quality_Score,
                         COUNT(*) AS MTCount
                  FROM T_Mass_Tags
                  GROUP BY PMT_Quality_Score ) LookupQ
       ON QualityScores.PMT_Quality_Score <= LookupQ.PMT_Quality_Score
GROUP BY QualityScores.PMT_Quality_Score


GO
