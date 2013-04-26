/****** Object:  StoredProcedure [dbo].[usp_JobStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_JobStats] (@InsertFlag BIT = 0)
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
***************************************************************************************************************/

BEGIN

SELECT sj.job_id, 
		sj.name,
		sc.name AS Category,
		sj.[Enabled], 
		sjs.last_run_outcome,
        (SELECT MAX(run_date) 
			FROM msdb..sysjobhistory(nolock) sjh 
			WHERE sjh.job_id = sj.job_id) AS last_run_date
INTO #TEMP
FROM msdb..sysjobs(nolock) sj
JOIN msdb..sysjobservers(nolock) sjs
    ON sjs.job_id = sj.job_id
JOIN msdb..syscategories sc
	ON sj.category_id = sc.category_id	

SELECT
	t.name AS JobName,
	t.Category,
	t.[Enabled],
	COALESCE(MAX(ja.start_execution_date),0) AS [StartTime],
	COALESCE(MAX(ja.stop_execution_date),0) AS [StopTime],
	COALESCE(AvgRunTime,0) AS AvgRunTime,
	CASE 
		WHEN ja.stop_execution_date IS NULL THEN DATEDIFF(ss,ja.start_execution_date,GETDATE())
		ELSE DATEDIFF(ss,ja.start_execution_date,ja.stop_execution_date) END AS [LastRunTime],
	CASE 
			WHEN ja.stop_execution_date IS NULL AND ja.start_execution_date IS NOT NULL THEN
				CASE WHEN DATEDIFF(ss,ja.start_execution_date,GETDATE())
					> (AvgRunTime + AvgRunTime * .25) THEN 'LongRunning-NOW'				
				ELSE 'NormalRunning-NOW'
				END
			WHEN DATEDIFF(ss,ja.start_execution_date,ja.stop_execution_date) 
				> (AvgRunTime + AvgRunTime * .25) THEN 'LongRunning-History'
			WHEN ja.stop_execution_date IS NULL AND ja.start_execution_date IS NULL THEN 'NA'
			ELSE 'NormalRunning-History'
	END AS [RunTimeStatus],	
	CASE
		WHEN ja.stop_execution_date IS NULL AND ja.start_execution_date IS NOT NULL THEN 'InProcess'
		WHEN ja.stop_execution_date IS NOT NULL AND t.last_run_outcome = 3 THEN 'CANCELLED'
		WHEN ja.stop_execution_date IS NOT NULL AND t.last_run_outcome = 0 THEN 'ERROR'			
		WHEN ja.stop_execution_date IS NOT NULL AND t.last_run_outcome = 1 THEN 'SUCCESS'			
		ELSE 'NA'
	END AS [LastRunOutcome]
INTO #TEMP2
FROM #TEMP AS t
LEFT OUTER
JOIN (SELECT MAX(session_id) as session_id,job_id FROM msdb.dbo.sysjobactivity(nolock) WHERE run_requested_date IS NOT NULL GROUP BY job_id) AS ja2
	ON t.job_id = ja2.job_id
LEFT OUTER
JOIN msdb.dbo.sysjobactivity(nolock) ja
	ON ja.session_id = ja2.session_id and ja.job_id = t.job_id
LEFT OUTER 
JOIN (SELECT job_id,
			AVG	((run_duration/10000 * 3600) + ((run_duration%10000)/100*60) + (run_duration%10000)%100) + 	STDEV ((run_duration/10000 * 3600) + ((run_duration%10000)/100*60) + (run_duration%10000)%100) AS [AvgRuntime]
		FROM msdb..sysjobhistory(nolock)
		WHERE step_id = 0 AND run_status = 1 and run_duration >= 0
		GROUP BY job_id) art 
	ON t.job_id = art.job_id
GROUP BY t.name,t.Category,t.[Enabled],t.last_run_outcome,ja.start_execution_date,ja.stop_execution_date,AvgRunTime
ORDER BY t.name

SELECT * FROM #TEMP2

IF @InsertFlag = 1
BEGIN

INSERT INTO [dba].dbo.JobStatsHistory (JobName,Category,[Enabled],StartTime,StopTime,[AvgRunTime],[LastRunTime],RunTimeStatus,LastRunOutcome) 
SELECT JobName,Category,[Enabled],StartTime,StopTime,[AvgRunTime],[LastRunTime],RunTimeStatus,LastRunOutcome
FROM #TEMP2

UPDATE [dba].dbo.JobStatsHistory
SET JobStatsID = (SELECT COALESCE(MAX(JobStatsID),0) + 1 FROM [dba].dbo.JobStatsHistory)
WHERE JobStatsID IS NULL

END
DROP TABLE #TEMP
DROP TABLE #TEMP2
END

GO
