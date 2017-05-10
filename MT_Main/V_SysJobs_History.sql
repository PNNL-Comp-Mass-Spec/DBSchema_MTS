/****** Object:  View [dbo].[V_SysJobs_History] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_SysJobs_History]
AS
SELECT C.Name AS Category,
       V.Name AS Job,
       V.Job_ID,
       H.message,
	   Convert(date, 
         Substring(Convert(varchar(12), H.run_date), 1, 4) + '-' + 
         Substring(Convert(varchar(12), H.run_date), 5, 2) + '-' + 
         Substring(Convert(varchar(12), H.run_date), 7, 2)) AS RunDate,
       H.run_duration / 10000 * 60 + H.run_duration / 100 % 100 + H.run_duration % 100 / 60.0 AS RunDuration_Minutes
FROM msdb.dbo.sysjobhistory H
     INNER JOIN msdb.dbo.sysjobs_view V
       ON V.job_id = H.Job_ID
     INNER JOIN msdb.dbo.syscategories C
       ON V.category_id = C.category_ID
WHERE H.run_date >= Convert(varchar(24), DateAdd(YEAR, - 2, GetDate()), 112)  -- Limit to jobs in the last 2 years


GO
