/****** Object:  View [dbo].[V_PeptideHit_Job_Scan_Stats_Ex] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_PeptideHit_Job_Scan_Stats_Ex
AS
SELECT InnerQ.Job, TAD.Campaign, TAD.Experiment, TAD.Dataset,
    TotalScanCount, FragScanCount, 
    UniqueFragScanCountHighScore, 
    UniquePeptideCountHighScore, 
    Round(UniqueFragScanCountHighScore / CONVERT(float, 
    FragScanCount) * 100, 2) 
    AS PercentFragScanCountHighScore
FROM (SELECT dbo.T_Peptides.Analysis_ID AS Job, 
          dbo.V_PeptideHit_Job_Scan_Stats.TotalScanCount, 
          dbo.V_PeptideHit_Job_Scan_Stats.FragScanCount, 
          COUNT(DISTINCT dbo.T_Peptides.Scan_Number) 
          AS UniqueFragScanCountHighScore, 
          COUNT(DISTINCT dbo.T_Peptides.Seq_ID) 
          AS UniquePeptideCountHighScore
      FROM dbo.T_Peptides INNER JOIN
          dbo.T_Score_Discriminant ON 
          dbo.T_Peptides.Peptide_ID = dbo.T_Score_Discriminant.Peptide_ID
           INNER JOIN
          dbo.V_PeptideHit_Job_Scan_Stats ON 
          dbo.T_Peptides.Analysis_ID = dbo.V_PeptideHit_Job_Scan_Stats.Job
      WHERE (dbo.T_Score_Discriminant.DiscriminantScoreNorm >=
           .8)
      GROUP BY dbo.T_Peptides.Analysis_ID, 
          dbo.V_PeptideHit_Job_Scan_Stats.TotalScanCount, 
          dbo.V_PeptideHit_Job_Scan_Stats.FragScanCount) 
    AS InnerQ INNER JOIN
    T_Analysis_Description AS TAD ON TAD.Job = InnerQ.Job


GO
