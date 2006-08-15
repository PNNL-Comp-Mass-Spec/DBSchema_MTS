/****** Object:  StoredProcedure [dbo].[SQLServerAgentJobStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.SQLServerAgentJobStats
/****************************************************
** 
**	Desc:	Queries tables in MSDB to count the number of
			SQL Server Agent jobs that are currently running
**
**			This code was extracted from MSDB.dbo.sp_get_composite_job_info
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	mem
**	Date:	03/10/2006
**			03/14/2006 mem - Added parameter @JobCategoryExclusionFilter
**    
*****************************************************/
(
	@JobNameExclusionFilter varchar(128) = '%Unpause%',			-- Will ignore jobs with names matching this filter when counting the number of running jobs
	@JobCategoryExclusionFilter varchar(128) = '%Continuous%',	-- Will ignore jobs with job categories matching this filter when counting the number of running jobs
	@JobRunningCount int = 0 output
)
As
	Set NoCount On

	-- Job Execution Status Values
	-- 0 = Not idle or suspended
	-- 1 = Executing
	-- 2 = Waiting For Thread
	-- 3 = Between Retries
	-- 4 = Idle
	-- 5 = Suspended
	-- [6 = WaitingForStepToFinish]
	-- 7 = PerformingCompletionActions

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	-- Clear the output parameters
	Set @JobRunningCount = 0

	Declare @job_id UNIQUEIDENTIFIER
	Set @job_id = Null

	Declare @is_sysadmin INT
	Declare @job_owner   sysname

	-- Step 1: Create intermediate work tables
	CREATE TABLE #xp_results (
		job_id                UNIQUEIDENTIFIER NOT NULL,
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
		job_state             INT              NOT NULL
	)

	CREATE TABLE #filtered_jobs (
		[name]					 NVARCHAR (128) NULL,
		job_id                   UNIQUEIDENTIFIER NOT NULL,
        date_created             DATETIME         NOT NULL,
        date_last_modified       DATETIME         NOT NULL,
        current_execution_status INT              NULL,
        current_execution_step   sysname          COLLATE database_default NULL,
        current_retry_attempt    INT              NULL,
        last_run_date            INT              NOT NULL,
        last_run_time            INT              NOT NULL,
        last_run_outcome         INT              NOT NULL,
        next_run_date            INT              NULL,
        next_run_time            INT              NULL,
        next_run_schedule_id     INT              NULL
       )

	CREATE TABLE #job_execution_state (
		job_id                  UNIQUEIDENTIFIER NOT NULL,
		date_started            INT              NOT NULL,
		time_started            INT              NOT NULL,
		execution_job_status    INT              NOT NULL,
		execution_step_id       INT              NULL,
		execution_step_name     sysname          COLLATE database_default NULL,
		execution_retry_attempt INT              NOT NULL,
		next_run_date           INT              NOT NULL,
		next_run_time           INT              NOT NULL,
		next_run_schedule_id    INT              NOT NULL
	)
	
	-- Step 2: Capture job execution information (for local jobs only since that's all SQLServerAgent caches)
	SELECT @is_sysadmin = ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0)
	SELECT @job_owner = SUSER_SNAME()

	IF ((@@microsoftversion / 0x01000000) >= 8) -- SQL Server 8.0 or greater
		INSERT INTO #xp_results
		EXECUTE master.dbo.xp_sqlagent_enum_jobs @is_sysadmin, @job_owner, @job_id
	ELSE
		INSERT INTO #xp_results
		EXECUTE master.dbo.xp_sqlagent_enum_jobs @is_sysadmin, @job_owner

	INSERT INTO #job_execution_state
	SELECT xpr.job_id,
		xpr.last_run_date,
		xpr.last_run_time,
		xpr.job_state,
		sjs.step_id,
		sjs.step_name,
		xpr.current_retry_attempt,
		xpr.next_run_date,
		xpr.next_run_time,
		xpr.next_run_schedule_id
	FROM #xp_results xpr
	LEFT OUTER JOIN msdb.dbo.sysjobsteps sjs ON ((xpr.job_id = sjs.job_id) AND 
												 (xpr.current_step = sjs.step_id)), 
					msdb.dbo.sysjobs_view sjv
	WHERE (sjv.job_id = xpr.job_id)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	INSERT INTO #filtered_jobs
	SELECT DISTINCT
		sjv.[name],
		sjv.job_id,
		sjv.date_created,
		sjv.date_modified,
		ISNULL(jes.execution_job_status, 4), -- Will be NULL if the job is non-local or is not in #job_execution_state (NOTE: 4 = STATE_IDLE)
		CASE ISNULL(jes.execution_step_id, 0)
			WHEN 0 THEN NULL                   -- Will be NULL if the job is non-local or is not in #job_execution_state
			ELSE CONVERT(NVARCHAR, jes.execution_step_id) + N' (' + jes.execution_step_name + N')'
		END,
		jes.execution_retry_attempt,         -- Will be NULL if the job is non-local or is not in #job_execution_state
		0,  -- last_run_date placeholder    (we'll fix it up in step 3.3)
		0,  -- last_run_time placeholder    (we'll fix it up in step 3.3)
		5,  -- last_run_outcome placeholder (we'll fix it up in step 3.3 - NOTE: We use 5 just in case there are no jobservers for the job)
		jes.next_run_date,                   -- Will be NULL if the job is non-local or is not in #job_execution_state
		jes.next_run_time,                   -- Will be NULL if the job is non-local or is not in #job_execution_state
		jes.next_run_schedule_id            -- Will be NULL if the job is non-local or is not in #job_execution_state
	FROM msdb.dbo.sysjobs_view sjv
		LEFT OUTER JOIN #job_execution_state jes ON (sjv.job_id = jes.job_id)
		LEFT OUTER JOIN msdb.dbo.sysjobsteps sjs ON (sjv.job_id = sjs.job_id)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Step 3.1: Change the execution status of non-local jobs from 'Idle' to 'Unknown'
	UPDATE #filtered_jobs
	SET current_execution_status = NULL
	WHERE (current_execution_status = 4)
	AND (job_id IN (SELECT job_id
					FROM msdb.dbo.sysjobservers
					WHERE (server_id <> 0)))
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Step 3.3: Populate the last run date/time/outcome [this is a little tricky since for
	--           multi-server jobs there are multiple last run details in sysjobservers, so
	--           we simply choose the most recent].
	IF (EXISTS (SELECT *
				FROM msdb.dbo.systargetservers))
	BEGIN
		UPDATE #filtered_jobs
		SET last_run_date = sjs.last_run_date,
			last_run_time = sjs.last_run_time,
			last_run_outcome = sjs.last_run_outcome
		FROM #filtered_jobs fj,
				msdb.dbo.sysjobservers sjs
		WHERE (CONVERT(FLOAT, sjs.last_run_date) * 1000000) + sjs.last_run_time =
				(SELECT MAX((CONVERT(FLOAT, last_run_date) * 1000000) + last_run_time)
				FROM msdb.dbo.sysjobservers
				WHERE (job_id = sjs.job_id))
			AND (fj.job_id = sjs.job_id)
		END
	ELSE
	BEGIN
		UPDATE #filtered_jobs
		SET last_run_date = sjs.last_run_date,
			last_run_time = sjs.last_run_time,
			last_run_outcome = sjs.last_run_outcome
		FROM #filtered_jobs fj,
				msdb.dbo.sysjobservers sjs
		WHERE (fj.job_id = sjs.job_id)
	END

	SELECT @JobRunningCount = COUNT(*)
	FROM (
		SELECT fj.*, ISNULL(sc.name, FORMATMESSAGE(14205)) as Category
		FROM #filtered_jobs fj LEFT OUTER JOIN 
			msdb.dbo.sysjobs_view  sjv ON (fj.job_id = sjv.job_id) LEFT OUTER JOIN 
			msdb.dbo.syscategories sc  ON (sjv.category_id = sc.category_id)
		WHERE (fj.current_execution_status IN (1,2,3))
		) LookupQ
	WHERE NOT [Name] LIKE @JobNameExclusionFilter AND
		  NOT [Category] LIKE @JobCategoryExclusionFilter
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


Done:

	DROP TABLE #job_execution_state
	DROP TABLE #filtered_jobs
	DROP TABLE #xp_results

	return @myError

GO
