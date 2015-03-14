/****** Object:  View [dbo].[V_PeptideHit_Job_Scan_Max] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_PeptideHit_Job_Scan_Max
AS
SELECT Q1.Job,
       Q1.MaxScanNumberPeptideHit,
       Q2.MaxScanNumberSICs,
       Q3.MaxScanNumberAllScans
FROM ( SELECT TAD.Job,
              MAX(dbo.T_Peptides.Scan_Number) AS MaxScanNumberPeptideHit
       FROM dbo.T_Analysis_Description TAD
            INNER JOIN dbo.T_Peptides
              ON TAD.Job = dbo.T_Peptides.Job
       WHERE TAD.ResultType LIKE '%Peptide_Hit'
       GROUP BY TAD.Job 
     ) Q1
     LEFT OUTER JOIN ( SELECT TAD.Job,
                              MAX(DSS.Scan_Number) AS MaxScanNumberAllScans
                       FROM dbo.T_Analysis_Description TAD
                            INNER JOIN dbo.V_SIC_Job_to_PeptideHit_Map JobMap
                              ON TAD.Job = JobMap.Job
                            INNER JOIN dbo.T_Dataset_Stats_Scans DSS
                              ON JobMap.SIC_Job = DSS.Job
                       GROUP BY TAD.Job 
                       ) Q3
       ON Q1.Job = Q3.Job
     LEFT OUTER JOIN ( SELECT TAD.Job,
                              MAX(DSSIC.Frag_Scan_Number) AS MaxScanNumberSICs
                       FROM dbo.T_Analysis_Description TAD
                            INNER JOIN dbo.V_SIC_Job_to_PeptideHit_Map JobMap
                              ON TAD.Job = JobMap.Job
                            INNER JOIN dbo.T_Dataset_Stats_SIC DSSIC
                              ON JobMap.SIC_Job = DSSIC.Job
                       GROUP BY TAD.Job 
                     ) Q2
       ON Q1.Job = Q2.Job

GO
GRANT VIEW DEFINITION ON [dbo].[V_PeptideHit_Job_Scan_Max] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_PeptideHit_Job_Scan_Max] TO [MTS_DB_Lite] AS [dbo]
GO
