CREATE VIEW dbo.V_Tuning_QueryExecutionStats
AS
SELECT QS.total_worker_time / QS.execution_count AS Avg_CPU_Time,
        SUBSTRING(st.text, (qs.statement_start_offset / 2) + 1, 
           ((CASE qs.statement_end_offset 
             WHEN -1 
             THEN DATALENGTH(st.text)
             ELSE qs.statement_end_offset
             END - qs.statement_start_offset) / 2) + 1) AS SqlText,
       QS.creation_time,
       QS.last_execution_time,
       QS.Execution_Count,
       Convert(decimal(18, 3), QS.total_worker_time / 1000000.0) AS total_worker_time_sec,
       Convert(decimal(18, 3), QS.last_worker_time / 1000000.0) AS last_worker_time_sec,
       Convert(decimal(18, 3), QS.min_worker_time / 1000000.0) AS min_worker_time_sec,
       Convert(decimal(18, 3), QS.max_worker_time / 1000000.0) AS max_worker_time_sec,
       Convert(decimal(18, 3), QS.total_elapsed_time / 1000000.0) AS total_elapsed_time_sec,
       Convert(decimal(18, 3), QS.last_elapsed_time / 1000000.0) AS last_elapsed_time_sec,
       Convert(decimal(18, 3), QS.min_elapsed_time / 1000000.0) AS min_elapsed_time_sec,
       Convert(decimal(18, 3), QS.max_elapsed_time / 1000000.0) AS max_elapsed_time_sec,
       QS.sql_handle,
       QS.plan_handle,
       ST.DBID,
       SD.Name AS DatabaseName,
       ST.Encrypted
FROM sys.dm_exec_query_stats AS QS
     CROSS APPLY sys.dm_exec_sql_text ( qs.sql_handle ) AS st
     LEFT OUTER JOIN sys.databases SD
       ON ST.DBID = SD.database_ID
WHERE NOT IsNull(SD.Name, '') IN ('master', 'msdb')
GO
