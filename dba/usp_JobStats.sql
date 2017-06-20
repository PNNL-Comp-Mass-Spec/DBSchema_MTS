/****** Object:  StoredProcedure [dbo].[usp_JobStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC dbo.usp_JobStats (@InsertFlag BIT = 0)
AS

/**************************************************************************************************************
**  Purpose: 
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  02/21/2012		Michael Rounds			1.0				Comments creation
**  03/13/2012		Michael Rounds			1.1				Added join to syscategories to pull in Category name
**	04/24/2013		Volker.Bachmann from SSC 1.1.1			Added COALESCE to MAX(ja.start_execution_date) and MAX(ja.stop_execution_date)
**	05/01/2013		Michael Rounds			1.2				Creating temp tables instead of inserting INTO
**															Removed COALESCE's from previous change on 4/24. Causing dates to read 1/1/1900 when NULL. Would rather have NULL.
**	05/17/2013		Michael Rounds			1.2.1			Added Job Owner to JobStatsHistory
**	07/23/2013		Michael Rounds			1.3				Tweaked to support Case-sensitive
**	06/19/2017		Matthew Monroe			1.3.1			Use xp_sqlagent_enum_jobs to confirm that jobs are actually running
***************************************************************************************************************/

BEGIN

CREATE TABLE #TEMP (
	Job_ID NVARCHAR(255),
	[Owner] NVARCHAR(255),
	Name NVARCHAR(128),
	Category NVARCHAR(128),
	[Enabled] BIT,
	Last_Run_Outcome INT,
	Last_Run_Date NVARCHAR(20)
	)
	
CREATE TABLE #TEMP2 (
	JobName NVARCHAR(128),
	[Owner] NVARCHAR(255),
	Category NVARCHAR(128),
	[Enabled] BIT,
	StartTime DATETIME,
	StopTime DATETIME,
	AvgRunTime NUMERIC(20,10),
	LastRunTime INT,
	RunTimeStatus NVARCHAR(128),
	LastRunOutcome NVARCHAR(20)
	)

-- If a job was running while the server restarted, it will appear that the job is still running even though it isn't
-- Use xp_sqlagent_enum_jobs to find jobs that are actually running

CREATE TABLE #JobStatus 
           (job_id               UNIQUEIDENTIFIER NOT NULL,  
           last_run_date         INT              NOT NULL,  
           last_run_time         INT              NOT NULL,  
           next_run_date         INT              NOT NULL,  
           next_run_time         INT              NOT NULL,  
           next_run_schedule_id  INT              NOT NULL,  
           requested_to_run      INT              NOT NULL, -- BOOL  
           request_source        INT              NOT NULL,  
           request_source_id     sysname          COLLATE database_default NULL,  
           running               INT              NOT NULL, -- BOOL  
           current_step          INT              NOT NULL,  
           current_retry_attempt INT              NOT NULL,  
           job_state             INT              NOT NULL) 

INSERT INTO #JobStatus
EXEC master.dbo.xp_sqlagent_enum_jobs 1,dbo

INSERT INTO #TEMP (Job_ID,[Owner],Name,Category,[Enabled],Last_Run_Outcome,Last_Run_Date)
SELECT sj.job_id,
	SUSER_SNAME(sj.owner_sid) AS [Owner],
		sj.name,
		sc.name AS Category,
		sj.[Enabled], 
		sjs.last_run_outcome,
        (SELECT MAX(run_date) 
			FROM msdb..sysjobhistory(nolock) sjh 
			WHERE sjh.job_id = sj.job_id) AS last_run_date
FROM msdb..sysjobs(nolock) sj
JOIN msdb..sysjobservers(nolock) sjs
    ON sjs.job_id = sj.job_id
JOIN msdb..syscategories sc
	ON sj.category_id = sc.category_id	

INSERT INTO #TEMP2 (JobName,[Owner],Category,[Enabled],StartTime,StopTime,AvgRunTime,LastRunTime,RunTimeStatus,LastRunOutcome)
SELECT
	t.name AS JobName,
	t.[Owner],
	t.Category,
	t.[Enabled],
	MAX(ja.start_execution_date) AS [StartTime],
	MAX(ja.stop_execution_date) AS [StopTime],
	COALESCE(AvgRunTime,0) AS AvgRunTime,
	CASE 
		WHEN ja.stop_execution_date IS NULL THEN
			CASE WHEN IsNull(JobStatus.Running, 0) > 0 THEN DATEDIFF(ss,ja.start_execution_date,GETDATE()) ELSE NULL END
		ELSE DATEDIFF(ss,ja.start_execution_date,ja.stop_execution_date) END AS [LastRunTime],
	CASE 
			WHEN ja.stop_execution_date IS NULL AND ja.start_execution_date IS NOT NULL THEN
				CASE WHEN IsNull(JobStatus.Running, 0) > 0 AND DATEDIFF(ss,ja.start_execution_date,GETDATE())
					> (AvgRunTime + AvgRunTime * .25) THEN 'LongRunning-NOW'				
				WHEN IsNull(JobStatus.Running, 0) > 0 THEN 'NormalRunning-NOW'
				ELSE 'Aborted'
				END
			WHEN DATEDIFF(ss,ja.start_execution_date,ja.stop_execution_date) 
				> (AvgRunTime + AvgRunTime * .25) THEN 'LongRunning-History'
			WHEN ja.stop_execution_date IS NULL AND ja.start_execution_date IS NULL THEN 'NA'
			ELSE 'NormalRunning-History'
	END AS [RunTimeStatus],	
	CASE
		WHEN ja.stop_execution_date IS NULL AND ja.start_execution_date IS NOT NULL THEN 
			CASE WHEN IsNull(JobStatus.Running, 0) > 0 THEN 'InProcess' ELSE 'ABORTED' End
		WHEN ja.stop_execution_date IS NOT NULL AND t.last_run_outcome = 3 THEN 'CANCELLED'
		WHEN ja.stop_execution_date IS NOT NULL AND t.last_run_outcome = 0 THEN 'ERROR'			
		WHEN ja.stop_execution_date IS NOT NULL AND t.last_run_outcome = 1 THEN 'SUCCESS'			
		ELSE 'NA'
	END AS [LastRunOutcome]
FROM #TEMP AS t
LEFT OUTER
JOIN (SELECT MAX(session_id) as session_id,job_id FROM msdb..sysjobactivity(nolock) WHERE run_requested_date IS NOT NULL GROUP BY job_id) AS ja2
	ON t.job_id = ja2.job_id
LEFT OUTER
JOIN (SELECT Cast(job_id as nvarchar(255)) AS job_id, running FROM #JobStatus) AS JobStatus
	ON t.job_id = JobStatus.job_id
LEFT OUTER
JOIN msdb..sysjobactivity(nolock) ja
	ON ja.session_id = ja2.session_id and ja.job_id = t.job_id
LEFT OUTER 
JOIN (SELECT job_id,
			AVG	((run_duration/10000 * 3600) + ((run_duration%10000)/100*60) + (run_duration%10000)%100) + 	STDEV ((run_duration/10000 * 3600) + ((run_duration%10000)/100*60) + (run_duration%10000)%100) AS [AvgRunTime]
		FROM msdb..sysjobhistory(nolock)
		WHERE step_id = 0 AND run_status = 1 and run_duration >= 0
		GROUP BY job_id) art 
	ON t.job_id = art.job_id
GROUP BY t.name,t.[Owner],t.Category,t.[Enabled],t.last_run_outcome,ja.start_execution_date,ja.stop_execution_date,AvgRunTime,JobStatus.Running
ORDER BY t.name

SELECT * FROM #TEMP2

IF @InsertFlag = 1
BEGIN

INSERT INTO [dba].dbo.JobStatsHistory (JobName,[Owner],Category,[Enabled],StartTime,StopTime,[AvgRunTime],[LastRunTime],RunTimeStatus,LastRunOutcome) 
SELECT JobName,[Owner],Category,[Enabled],StartTime,StopTime,[AvgRunTime],[LastRunTime],RunTimeStatus,LastRunOutcome
FROM #TEMP2

UPDATE [dba].dbo.JobStatsHistory
SET JobStatsID = (SELECT COALESCE(MAX(JobStatsID),0) + 1 FROM [dba].dbo.JobStatsHistory)
WHERE JobStatsID IS NULL

END
DROP TABLE #TEMP
DROP TABLE #TEMP2
END


GO
