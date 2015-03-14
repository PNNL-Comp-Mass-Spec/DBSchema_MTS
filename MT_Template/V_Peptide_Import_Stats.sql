/****** Object:  View [dbo].[V_Peptide_Import_Stats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE VIEW dbo.V_Peptide_Import_Stats
AS
SELECT Entry_ID,
       posting_time,
       CONVERT(int, SUBSTRING(message, 14, PeptideIndex - 15)) AS PeptidesLoaded,
       CONVERT(int, SUBSTRING(message, PeptideIndex + 12, SecondsIndex - (PeptideIndex + 13))) AS Seconds,
       CONVERT(int, SUBSTRING(message, SecondsIndex + 12, JobIndex - (SecondsIndex + 13))) AS Jobs,
       CONVERT(real, SUBSTRING(message, JobIndex + JobIndexLength - 1, PeptidesPerSecIndex - (JobIndex + JobIndexLength))) AS PeptidesPerSec
FROM ( SELECT Entry_ID,
              posting_time,
              message,
              PeptideIndex,
              SecondsIndex,
              CASE
                  WHEN JobsIndex > 0 THEN JobsIndex
                  ELSE JobIndex
              END AS JobIndex,
              CASE
                  WHEN JobsIndex > 0 THEN 7
                  ELSE 6
              END AS JobIndexLength,
              PeptidesPerSecIndex
       FROM ( SELECT Entry_ID,
                     posting_time,
                     message,
                     CHARINDEX('peptides', message) AS PeptideIndex,
                     CHARINDEX('seconds', message) AS SecondsIndex,
                     CHARINDEX('jobs', message) AS JobsIndex,
                     CHARINDEX('job', message) AS JobIndex,
                     CHARINDEX('peptides/sec', message) AS PeptidesPerSecIndex
              FROM dbo.T_Log_Entries
              WHERE (posted_by = 'UpdateMassTagsFromMultipleAnalysis') AND
                    (message LIKE 'batch loaded%')
        ) LookupQ 
     ) OuterQ


GO
GRANT VIEW DEFINITION ON [dbo].[V_Peptide_Import_Stats] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_Peptide_Import_Stats] TO [MTS_DB_Lite] AS [dbo]
GO
