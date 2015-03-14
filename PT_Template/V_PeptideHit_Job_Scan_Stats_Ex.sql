/****** Object:  View [dbo].[V_PeptideHit_Job_Scan_Stats_Ex] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_PeptideHit_Job_Scan_Stats_Ex
AS
SELECT InnerQ.Job,
       TAD.Campaign,
       TAD.Experiment,
       TAD.Dataset,
       TotalScanCount,
       FragScanCount,
       UniqueFragScanCountHighScore,
       UniquePeptideCountHighScore,
       Round(UniqueFragScanCountHighScore / CONVERT(float, FragScanCount) * 100, 2) AS 
         PercentFragScanCountHighScore
FROM ( SELECT Pep.Job,
              JSS.TotalScanCount,
              JSS.FragScanCount,
              COUNT(DISTINCT Pep.Scan_Number) AS UniqueFragScanCountHighScore,
              COUNT(DISTINCT Pep.Seq_ID) AS UniquePeptideCountHighScore
       FROM T_Peptides Pep
            INNER JOIN T_Score_Discriminant SD
              ON Pep.Peptide_ID = SD.Peptide_ID
            INNER JOIN V_PeptideHit_Job_Scan_Stats JSS
              ON Pep.Job = JSS.Job
       WHERE (SD.DiscriminantScoreNorm >= 0.8)
       GROUP BY Pep.Job, JSS.TotalScanCount, JSS.FragScanCount 
     ) AS InnerQ
     INNER JOIN T_Analysis_Description AS TAD
       ON TAD.Job = InnerQ.Job

GO
GRANT VIEW DEFINITION ON [dbo].[V_PeptideHit_Job_Scan_Stats_Ex] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_PeptideHit_Job_Scan_Stats_Ex] TO [MTS_DB_Lite] AS [dbo]
GO
