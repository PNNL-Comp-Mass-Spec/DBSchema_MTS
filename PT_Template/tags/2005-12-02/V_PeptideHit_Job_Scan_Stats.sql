SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_PeptideHit_Job_Scan_Stats]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_PeptideHit_Job_Scan_Stats]
GO


CREATE VIEW dbo.V_PeptideHit_Job_Scan_Stats
AS
SELECT dbo.T_Analysis_Description.Job, 
    COUNT(dbo.T_Dataset_Stats_Scans.Scan_Number) 
    AS TotalScanCount, 
    SUM(CASE WHEN scan_type = 2 THEN 1 ELSE 0 END) 
    AS FragScanCount
FROM dbo.T_Analysis_Description INNER JOIN
    dbo.V_SIC_Job_to_PeptideHit_Map ON 
    dbo.T_Analysis_Description.Job = dbo.V_SIC_Job_to_PeptideHit_Map.Job
     INNER JOIN
    dbo.T_Dataset_Stats_Scans ON 
    dbo.V_SIC_Job_to_PeptideHit_Map.SIC_Job = dbo.T_Dataset_Stats_Scans.Job
WHERE (dbo.T_Analysis_Description.ResultType = 'peptide_hit')
GROUP BY dbo.T_Analysis_Description.Job


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

