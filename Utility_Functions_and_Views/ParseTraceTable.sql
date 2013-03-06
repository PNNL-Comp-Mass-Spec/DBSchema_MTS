/*
** 	The following can be used to parse a Trace Results table saved from Sql Server Profiler
** 	It assumes that the table contains columns Rownumber, SqlHandle, and TextData
** 	The trace that will create this data is the Performance Statistics trace, with the extended event column SqlHandle included
**
** 	In the follwoing example, the Trace Results were saved using File->Save As->Trace Table, and written to T_Trace_DMS5_20080918
** 	This procedure determines the unique sqlHandle values in T_Trace_DMS5_20080918, stores them in T_TmpSqlHandles, then calls
**	sys.dm_exec_query_stats for each one to obtain the execution stats
**
**	Stats are stored in table T_Trace_QueryExecutionStats
**	Note that obtaining execution stats for ~1600 queries takes ~60 seconds
**
*/

-- Use the following when debugging to limit the number of queries parsed
Declare @MaxQueriesToProcess int
Set @MaxQueriesToProcess = 0

-- Enable the following when debugging to see the full set of stats for each query
Declare @ShowStatsForEachQuery tinyint
Set @ShowStatsForEachQuery = 0


Declare @QueriesProcessed int
Set @QueriesProcessed = 0
 
Declare @UniqueID int
Declare @sqlHandle varbinary(64)
Declare @sqlText varchar(8000)
Declare @continue tinyint

DECLARE @CreationTime datetime
DECLARE @LastExecutionTime datetime
DECLARE @ExecutionCount bigint
DECLARE @TotalWorkerTime bigint
DECLARE @LastWorkerTime bigint
DECLARE @MinWorkerTime bigint
DECLARE @MaxWorkerTime bigint
DECLARE @TotalElapsedTime bigint
DECLARE @LastElapsedTime bigint
DECLARE @MinElapsedTime bigint
DECLARE @MaxElapsedTime bigint

CREATE TABLE #T_TmpSqlHandles (
    RowNumber int,
    TextData  ntext,
    sqlHandle varbinary(64),
    UniqueID  int IDENTITY (1,1 )
)

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[T_Trace_QueryExecutionStats]') AND type in (N'U'))
	Drop Table T_Trace_QueryExecutionStats

CREATE TABLE T_Trace_QueryExecutionStats(
	sql_handle varbinary(64) NOT NULL,
	SqlText varchar(8000) NULL,
	creation_time datetime NOT NULL,
	last_execution_time datetime NOT NULL,
	execution_count bigint NOT NULL,
	total_worker_time_sec decimal(9,4) NOT NULL,
	last_worker_time_sec decimal(9,4) NOT NULL,
	min_worker_time_sec decimal(9,4) NOT NULL,
	max_worker_time_sec decimal(9,4) NOT NULL,
	total_elapsed_time_sec decimal(9,4) NOT NULL,
	last_elapsed_time_sec decimal(9,4) NOT NULL,
	min_elapsed_time_sec decimal(9,4) NOT NULL,
	max_elapsed_time_sec decimal(9,4) NOT NULL
)

-- Populate #T_TmpSqlHandles using T_Trace_DMS5_20080918
INSERT INTO #T_TmpSqlHandles( RowNumber,
                              TextData,
                              sqlHandle )
SELECT RowNumber,
       TextData,
       substring(sqlhandle, 1, 64)
FROM dbo.T_Trace_DMS5_20080918
WHERE RowNumber IN ( SELECT Min(RowNumber) AS RowFirst
                     FROM dbo.T_Trace_DMS5_20080918
                     WHERE NOT sqlhandle IS NULL AND
                           NOT textdata IS NULL AND
                           NOT textdata LIKE '<%' AND
                           NOT textdata LIKE 'begin tran%'
                     GROUP BY substring(sqlhandle, 1, 128) )
ORDER BY RowNumber

-- Display the number of rows added
select COUNT(*) AS DistinctQueriesFound
FROM #T_TmpSqlHandles

-- Loop through the entries in #T_TmpSqlHandles and call sys.dm_exec_query_stats for each
-- Populate T_Trace_QueryExecutionStats with useful results
Set @UniqueID = 0

Set @continue = 1
While @continue = 1
Begin
	SELECT TOP 1 @sqlHandle = sqlHandle,
				 @sqlText = Substring(TextData, 1, 8000),
				 @UniqueID = UniqueID
	FROM #T_TmpSqlHandles
	Where UniqueID > @UniqueID
	ORDER BY UniqueID

	If @@RowCount < 1
		Set @continue = 0
	Else
	Begin
		if @ShowStatsForEachQuery <> 0
			SELECT *
			FROM sys.dm_exec_query_stats
			WHERE sql_handle = @sqlHandle

		Set @ExecutionCount = 0
		SELECT @CreationTime = creation_time,
			   @LastExecutionTime = last_execution_time,
			   @ExecutionCount = execution_count,
			   @TotalWorkerTime = total_worker_time,
			   @LastWorkerTime = last_worker_time,
			   @MinWorkerTime = min_worker_time,
			   @MaxWorkerTime = max_worker_time,
			   @TotalElapsedTime = total_elapsed_time,
			   @LastElapsedTime = last_elapsed_time,
			   @MinElapsedTime = min_elapsed_time,
			   @MaxElapsedTime = max_elapsed_time
		FROM sys.dm_exec_query_stats
		WHERE sql_handle = @sqlHandle

		If @@RowCount > 0 And IsNull(@ExecutionCount, 0) > 0
		Begin
			INSERT INTO T_Trace_QueryExecutionStats( sql_handle, SqlText, creation_time, last_execution_time, execution_count,
										  total_worker_time_sec, last_worker_time_sec, min_worker_time_sec, max_worker_time_sec,
										  total_elapsed_time_sec, last_elapsed_time_sec, min_elapsed_time_sec, max_elapsed_time_sec )
			VALUES(@sqlHandle, @sqlText, @CreationTime, @LastExecutionTime, @ExecutionCount, 
				   @TotalWorkerTime/1000000.0, @LastWorkerTime/1000000.0, @MinWorkerTime/1000000.0, @MaxWorkerTime/1000000.0, 
				   @TotalElapsedTime/1000000.0, @LastElapsedTime/1000000.0, @MinElapsedTime/1000000.0, @MaxElapsedTime/1000000.0)
		End

	End

	Set @QueriesProcessed = @QueriesProcessed + 1
	If @MaxQueriesToProcess <> 0 And @QueriesProcessed >= @MaxQueriesToProcess
		Set @continue = 0
End

drop table #T_TmpSqlHandles


select * from T_Trace_QueryExecutionStats
