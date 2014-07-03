/****** Object:  StoredProcedure [dbo].[CacheQueryStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CacheQueryStats]
/****************************************************
**
**	Desc:
**		Stores the latest query execution stats in T_QueryStats
**		It is suggested to run this procedure every 4 hours 
**
**		Note that the stored values represent stats over the most recent interval
**		(time between the last time this procedure was called and this time)
**
**		Query text is stored in T_QueryText
**		The specific Sql Statement is visible using V_QueryText, which uses
**			SUBSTRING(QT.QueryText, QS.statement_start_offset / 2 + 1, 
**		           (CASE WHEN (QS.statement_end_offset = -1) 
**		                 THEN LEN(QT.QueryText) * 2
**		                 ELSE QS.statement_end_offset
**		            END - QS.statement_start_offset) / 2 + 1) AS Sql_Stmt
**
**		Expensive queries are logged to T_QueryStats_Expensive
**		by calling CacheExpensiveQueries
**	
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**			03/31/2014 - Initial release
**
*****************************************************/
(
	@infoOnly tinyint = 0,
	@CacheExpensiveQueries tinyint = 1
)
AS
	set nocount on
	
	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	
	DECLARE @interval_start smalldatetime,
	        @interval_end   smalldatetime
	
	------------------------------------------------------
	-- Create the temporary table to hold the stats
	------------------------------------------------------
	--
	CREATE TABLE [dbo].[#QS] (
	    [sql_handle]             [varbinary](64) NOT NULL,
	    [plan_handle]            [varbinary](64) NOT NULL,
	    [statement_start_offset] [int] NOT NULL,
	    [statement_end_offset]   [int] NOT NULL,
	    [objtype]                [nvarchar](20) NOT NULL,
	    [execution_count]        [bigint] NOT NULL,
	    [total_elapsed_time_ms]  [bigint] NOT NULL,
	    [min_elapsed_time_ms]    [bigint] NOT NULL,
	    [max_elapsed_time_ms]    [bigint] NOT NULL,
	    [total_worker_time_ms]   [bigint] NOT NULL,
	    [min_worker_time_ms]     [bigint] NOT NULL,
	    [max_worker_time_ms]     [bigint] NOT NULL,
	    [total_logical_reads]    [bigint] NOT NULL,
	    [min_logical_reads]      [bigint] NOT NULL,
	    [max_logical_reads]      [bigint] NOT NULL,
	    [total_physical_reads]   [bigint] NOT NULL,
	    [min_physical_reads]     [bigint] NOT NULL,
	    [max_physical_reads]     [bigint] NOT NULL,
	    [total_logical_writes]   [bigint] NOT NULL,
	    [min_logical_writes]     [bigint] NOT NULL,
	    [max_logical_writes]     [bigint] NOT NULL,
	    [creation_time]          [datetime] NOT NULL,
	    [last_execution_time]    [datetime] NOT NULL,
	    [DateAdded]              [datetime] NOT NULL
	)

	------------------------------------------------------
	-- Comment from the original author:
	--   This sounded like a great idea, but it just slowed it down several seconds.
	------------------------------------------------------
	--
	-- CREATE UNIQUE CLUSTERED INDEX TempQS_Cluster ON #QS ( sql_handle, plan_handle, statement_start_offset )
	
	------------------------------------------------------
	-- Validate the inputs
	------------------------------------------------------
	--

	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @CacheExpensiveQueries = IsNull(@CacheExpensiveQueries, 1)
	
	------------------------------------------------------
	-- Populate #QS with the overall query stats 
	-- (cumulative since the query plan was cached)
	------------------------------------------------------
	--
	-- The Cached Plans Object Type is in here in case you want to treat ad-hoc or prepared statements differently
	-- For example, uncomment the where clause after this insert query
	--
	INSERT INTO #QS
	SELECT qs.sql_handle,
	       qs.plan_handle,
	       qs.statement_start_offset,
	       qs.statement_end_offset,
	       cp.objtype,
	       qs.execution_count,
	       total_elapsed_time_ms = qs.total_elapsed_time / 1000,
	       min_elapsed_time_ms = qs.min_elapsed_time / 1000,
	       max_elapsed_time_ms = qs.max_elapsed_time / 1000,
	       total_worker_time_ms = qs.total_worker_time / 1000,
	       min_worker_time_ms = qs.min_worker_time / 1000,
	       max_worker_time_ms = qs.max_worker_time / 1000,
	       qs.total_logical_reads,
	       qs.min_logical_reads,
	       qs.max_logical_reads,
	       qs.total_physical_reads,
	       qs.min_physical_reads,
	       qs.max_physical_reads,
	       qs.total_logical_writes,
	       qs.min_logical_writes,
	       qs.max_logical_writes,
	       qs.creation_time,
	       qs.last_execution_time,
	       GetDate() AS DateAdded
	FROM sys.dm_exec_query_stats AS qs
	     INNER JOIN sys.dm_exec_cached_plans cp
	       ON qs.plan_handle = cp.plan_handle
	--WHERE cp.objtype NOT IN ('Adhoc')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
		
	If @infoOnly <> 0
	Begin
		SELECT *
		FROM #QS
		ORDER BY min_elapsed_time_ms DESC
		
		Goto Done
	End
	
	
	------------------------------------------------------
	-- Cache the full query text
	------------------------------------------------------
	--
	INSERT INTO T_QueryText (sql_handle, QueryText, DatabaseName, objtype)
	SELECT QS.sql_handle,
	       QueryText = qt.text,
	       DatabaseName = DB_NAME(max(qt.dbid)),
	       Max(QS.objtype)
	FROM ( SELECT #QS.sql_handle,
	              #QS.objtype
	       FROM #QS
	            LEFT JOIN T_QueryText QST
	              ON #QS.sql_handle = QST.sql_handle
	       WHERE QST.sql_handle IS NULL ) QS
	     CROSS APPLY sys.dm_exec_sql_text ( QS.sql_handle ) qt
	GROUP BY QS.sql_handle, qt.text
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	------------------------------------------------------
	-- Determine the interval timestamp bounds
	------------------------------------------------------
	--	
	SELECT TOP 1 @interval_start = dateadded
	FROM T_QueryStatsLast
	
	SELECT TOP 1 @interval_end = dateadded
	FROM #QS
	
	IF @interval_start IS NULL 
	BEGIN
	    SELECT @interval_start = create_date
	    FROM sys.databases
	    WHERE name = 'tempdb'
	END
	
	------------------------------------------------------
	-- Store the new query stats
	------------------------------------------------------
	--
	INSERT INTO T_QueryStats( interval_start,
	                          interval_end,
	                          sql_handle,
	                          plan_handle,
	                          statement_start_offset,
	                          statement_end_offset,
	                          execution_count,
	                          total_elapsed_time_ms,
	                          min_elapsed_time_ms,
	                          max_elapsed_time_ms,
	                          total_worker_time_ms,
	                          min_worker_time_ms,
	                          max_worker_time_ms,
	                          total_logical_reads,
	                          min_logical_reads,
	                          max_logical_reads,
	                          total_physical_reads,
	                          min_physical_reads,
	                          max_physical_reads,
	                          total_logical_writes,
	                          min_logical_writes,
	                          max_logical_writes,
	                          creation_time,
	                          last_execution_time )
	SELECT @interval_start,
	       @interval_end,
	       qs.sql_handle,
	       qs.plan_handle,
	       qs.statement_start_offset,
	       qs.statement_end_offset,
	       qs.execution_count - ISNULL(qsl.execution_count, 0),
	       qs.total_elapsed_time_ms - ISNULL(qsl.total_elapsed_time_ms, 0),
	       qs.min_elapsed_time_ms,
	       qs.max_elapsed_time_ms,
	       qs.total_worker_time_ms - ISNULL(qsl.total_worker_time_ms, 0),
	       qs.min_worker_time_ms,
	       qs.max_worker_time_ms,
	       qs.total_logical_reads - ISNULL(qsl.total_logical_reads, 0),
	       qs.min_logical_reads,
	       qs.max_logical_reads,
	       qs.total_physical_reads - ISNULL(qsl.total_physical_reads, 0),
	       qs.min_physical_reads,
	       qs.max_physical_reads,
	       qs.total_logical_writes - ISNULL(qsl.total_logical_writes, 0),
	       qs.min_logical_writes,
	   qs.max_logical_writes,
	       qs.creation_time,
	       qs.last_execution_time
	FROM #QS qs
	     LEFT OUTER JOIN T_QueryStatsLast qsl
	       ON qs.sql_handle = qsl.sql_handle AND
	          qs.plan_handle = qsl.plan_handle AND
	          qs.statement_start_offset = qsl.statement_start_offset AND
	          qs.creation_time = qsl.creation_time
	WHERE qs.execution_count - ISNULL(qsl.execution_count, 0) > 0
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	------------------------------------------------------
	-- Update T_QueryStatsLast to hold the most recent query stats
	------------------------------------------------------
	--
	
	TRUNCATE TABLE T_QueryStatsLast
	
	INSERT INTO T_QueryStatsLast
	SELECT sql_handle,
	       plan_handle,
	       statement_start_offset,
	       statement_end_offset,
	       objtype,
	       execution_count,
	       total_elapsed_time_ms,
	       min_elapsed_time_ms,
	       max_elapsed_time_ms,
	       total_worker_time_ms,
	       min_worker_time_ms,
	       max_worker_time_ms,
	       total_logical_reads,
	       min_logical_reads,
	       max_logical_reads,
	       total_physical_reads,
	       min_physical_reads,
	       max_physical_reads,
	       total_logical_writes,
	       min_logical_writes,
	       max_logical_writes,
	       creation_time,
	       last_execution_time,
	       DateAdded
	FROM #QS
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	------------------------------------------------------
	-- Optionally cache expensive queries
	------------------------------------------------------
	
	If @CacheExpensiveQueries <> 0
	Begin
		Exec CacheExpensiveQueries @infoOnly=0
	End

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError
	


GO
