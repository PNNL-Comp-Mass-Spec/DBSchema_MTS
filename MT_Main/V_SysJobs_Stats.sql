/****** Object:  View [dbo].[V_SysJobs_Stats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_SysJobs_Stats]
AS
SELECT Category,
       Job,
       Job_ID,
       RunDuration_Avg_Hours,
       RunDuration_Min_Hours,
       RunDuration_Max_Hours,
       Message,
       Convert(smalldatetime, 
         Substring(Convert(varchar(12), RunDate_First), 1, 4) + '-' + 
         Substring(Convert(varchar(12), RunDate_First), 5, 2) + '-' + 
         Substring(Convert(varchar(12), RunDate_First), 7, 2)) AS RunDate_First,
       Convert(smalldatetime, 
         Substring(Convert(varchar(12), RunDate_Last ), 1, 4) + '-' + 
         Substring(Convert(varchar(12), RunDate_Last ), 5, 2) + '-' + 
         Substring(Convert(varchar(12), RunDate_Last ), 7, 2)) AS RunDate_Last,
       Run_Count
FROM ( SELECT Category,
              Job,
              Job_ID,
              message,
              Min(run_date) AS RunDate_First,
              Max(run_date) AS RunDate_Last,
              Convert(decimal(18, 4), Avg(RunDuration_Hours)) AS RunDuration_Avg_Hours,
              Convert(decimal(18, 4), Min(RunDuration_Hours)) AS RunDuration_Min_Hours,
              Convert(decimal(18, 4), Max(RunDuration_Hours)) AS RunDuration_Max_Hours,
              COUNT(*) AS Run_Count
       FROM ( SELECT C.Name AS Category,
                     V.Name AS Job,
                     V.Job_ID,
                     H.message,
                     H.run_date,
                     H.run_duration / 10000 + H.run_duration / 100 % 100 / 60.0 
                     + H.run_duration % 100 / 3600.0 AS RunDuration_Hours
              FROM msdb.dbo.sysjobhistory H
                   INNER JOIN msdb.dbo.sysjobs_view V
                     ON V.job_id = H.Job_ID
                   INNER JOIN msdb.dbo.syscategories C
                     ON V.category_id = C.category_ID
              WHERE H.run_date >= Convert(varchar(24), DateAdd(YEAR, -2, GetDate()), 112)  -- Limit to jobs in the last 2 years
            ) FilterQ
       GROUP BY Category, Job, Job_ID, message 
	 ) LookupQ


GO
