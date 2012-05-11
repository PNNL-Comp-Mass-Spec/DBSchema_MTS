/****** Object:  View [dbo].[V_Peptides_DiscriminantScoreRange_Histogram] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_Peptides_DiscriminantScoreRange_Histogram
AS
SELECT DiscriminantScore_Bin, COUNT(*) AS Match_Count
FROM (SELECT CASE WHEN DiscriminantScoreNorm IS NULL 
          THEN 0 WHEN DiscriminantScoreNorm BETWEEN 
          0.0 AND 
          0.1 THEN 1 WHEN DiscriminantScoreNorm BETWEEN 
          0.1 AND 
          0.2 THEN 2 WHEN DiscriminantScoreNorm BETWEEN 
          0.2 AND 
          0.3 THEN 3 WHEN DiscriminantScoreNorm BETWEEN 
          0.3 AND 
          0.4 THEN 4 WHEN DiscriminantScoreNorm BETWEEN 
          0.4 AND 
          0.5 THEN 5 WHEN DiscriminantScoreNorm BETWEEN 
          0.5 AND 
          0.6 THEN 6 WHEN DiscriminantScoreNorm BETWEEN 
          0.6 AND 
          0.7 THEN 7 WHEN DiscriminantScoreNorm BETWEEN 
          0.7 AND 
          0.8 THEN 8 WHEN DiscriminantScoreNorm BETWEEN 
          0.8 AND 
          0.9 THEN 9 WHEN DiscriminantScoreNorm BETWEEN 
          0.9 AND 
          1.0 THEN 10 ELSE 0 END AS DiscriminantScore_Bin
      FROM dbo.T_Peptides INNER JOIN
          dbo.T_Analysis_Description ON 
          dbo.T_Peptides.Job = dbo.T_Analysis_Description.Job
           INNER JOIN
          dbo.T_Score_Discriminant ON 
          dbo.T_Peptides.Peptide_ID = dbo.T_Score_Discriminant.Peptide_ID)
     StatsQ
GROUP BY DiscriminantScore_Bin

GO
