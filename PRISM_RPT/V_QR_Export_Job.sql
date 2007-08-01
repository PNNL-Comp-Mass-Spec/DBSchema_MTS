/****** Object:  View [dbo].[V_QR_Export_Job] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_QR_Export_Job]
AS
SELECT TOP 100 PERCENT dbo.T_QR_Export_Job.jobkey AS [Key], 
    dbo.T_QR_Export_Job.modified AS Date, 
    dbo.T_Status.name AS Status, 
    dbo.T_QR_Export_Job.result AS Results, 
    dbo.T_QR_Export_Job.dbname, dbo.T_QR_Export_Job.qid_list, 
    dbo.T_QR_Export_Job.email_address, 
    dbo.T_QR_Export_Job.prot_column, 
    dbo.T_QR_Export_Job.pep_column, 
    dbo.T_QR_Export_Job.rep_cnt_avg_min, 
    dbo.T_QR_Export_Job.propep_select, 
    dbo.T_QR_Export_Job.crosstab_select, 
    dbo.T_QR_Export_Job.send_mail, 
    dbo.T_QR_Export_Job.gen_pep, 
    dbo.T_QR_Export_Job.include_prot, 
    dbo.T_QR_Export_Job.gen_prot, 
    dbo.T_QR_Export_Job.gen_prot_crosstab, 
    dbo.T_QR_Export_Job.prot_avg, 
    dbo.T_QR_Export_Job.gen_pep_crosstab, 
    dbo.T_QR_Export_Job.pep_avg, 
    dbo.T_QR_Export_Job.gen_propep_crosstab, 
    dbo.T_QR_Export_Job.Verbose_Output_Columns
FROM dbo.T_QR_Export_Job INNER JOIN
    dbo.T_Status ON 
    dbo.T_QR_Export_Job.statuskey = dbo.T_Status.statuskey
WHERE (DATEDIFF(Day, dbo.T_QR_Export_Job.modified, 
    { fn NOW() }) < 30)
ORDER BY dbo.T_QR_Export_Job.modified DESC


GO
