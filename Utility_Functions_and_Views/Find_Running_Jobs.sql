IF EXISTS (SELECT * FROM tempdb.dbo.sysobjects WHERE id = OBJECT_ID(N'[tempdb].[dbo].[T_Tmp_AgentJobInfo]'))
	TRUNCATE TABLE [tempdb].[dbo].[T_Tmp_AgentJobInfo]
Else
	CREATE TABLE [tempdb].[dbo].[T_Tmp_AgentJobInfo] (
	    job_id                uniqueidentifier NOT NULL,
	    last_run_date         nvarchar(20) NOT NULL,
	    last_run_time         nvarchar(20) NOT NULL,
	    next_run_date         nvarchar(20) NOT NULL,
	    next_run_time         nvarchar(20) NOT NULL,
	    next_run_schedule_id  int NOT NULL,
	    requested_to_run      int NOT NULL,
	    request_source        int NOT NULL,
	    request_source_id     sysname COLLATE database_default NULL,
	    running               int NOT NULL,
	    current_step          int NOT NULL,
	    current_retry_attempt int NOT NULL,
	    job_state             int NOT NULL
	)
	
DECLARE @job_owner   sysname
DECLARE @is_sysadmin   INT
SET @is_sysadmin   = isnull (is_srvrolemember ('sysadmin'), 0)
SET @job_owner   = suser_sname ()
INSERT INTO [tempdb].[dbo].[T_Tmp_AgentJobInfo]
 
--EXECUTE sys.xp_sqlagent_enum_jobs @is_sysadmin, @job_owner
EXECUTE master.dbo.xp_sqlagent_enum_jobs @is_sysadmin, @job_owner
UPDATE [tempdb].[dbo].[T_Tmp_AgentJobInfo]
SET last_run_time    = right ('000000' + last_run_time, 6),
next_run_time    = right ('000000' + next_run_time, 6)

SELECT j.name AS JobName,
       j.enabled AS Enabled,
       CASE x.running
           WHEN 1 THEN 'Running'
           ELSE CASE h.run_status
                    WHEN 2 THEN 'Inactive'
                    WHEN 4 THEN 'Inactive'
                    ELSE 'Completed'
                END
       END AS CurrentStatus,
       coalesce(x.current_step, 0) AS CurrentStepNbr,
       CASE
           WHEN x.last_run_date > 0 THEN convert(datetime, 
                                           substring(x.last_run_date, 1, 4) + '-' + 
                                             substring(x.last_run_date, 5, 2) + '-' + 
                                             substring(x.last_run_date, 7, 2) + ' ' + 
                                             substring(x.last_run_time, 1, 2) + ':' + 
                                             substring(x.last_run_time, 3, 2) + ':' + 
                                             substring(x.last_run_time, 5, 2) + '.000', 121)
           ELSE NULL
       END AS LastRunTime,
       CASE h.run_status
           WHEN 0 THEN 'Fail'
           WHEN 1 THEN 'Success'
           WHEN 2 THEN 'Retry'
           WHEN 3 THEN 'Cancel'
           WHEN 4 THEN 'In progress'
       END AS LastRunOutcome,
       CASE
           WHEN h.run_duration > 0 THEN (h.run_duration / 1000000) * (3600 * 24) + (h.run_duration / 
                                        10000 % 100) * 3600 + (h.run_duration / 100 % 100) * 60 
                                        + (h.run_duration % 100)
           ELSE NULL
       END AS LastRunDuration
FROM [tempdb].[dbo].[T_Tmp_AgentJobInfo] x
     LEFT JOIN msdb.dbo.sysjobs j
       ON x.job_id = j.job_id
     LEFT OUTER JOIN msdb.dbo.syscategories c
       ON j.category_id = c.category_id
     LEFT OUTER JOIN msdb.dbo.sysjobhistory h
       ON x.job_id = h.job_id AND
          x.last_run_date = h.run_date AND
          x.last_run_time = h.run_time AND
          h.step_id = 0
WHERE x.running = 1
