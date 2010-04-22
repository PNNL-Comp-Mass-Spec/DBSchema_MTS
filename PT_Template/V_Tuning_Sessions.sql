/****** Object:  View [dbo].[V_Tuning_Sessions] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE VIEW dbo.V_Tuning_Sessions
AS
SELECT S.session_id,
       S.login_name,
       S.Status,
       S.[program_name] AS Application,
       S.host_name,
       C.IP_Address,
       S.login_time,
       S.last_request_start_time AS "Last Batch",
       C.Last_Read,
       C.Last_Write,
       S.client_interface_name,
       C.most_recent_sql_handle,
       S.Deadlock_Priority,
       S.Row_Count,
       QueryStats.Avg_CPU_Time,
       QueryStats.SqlText,
       QueryStats.creation_time,
       QueryStats.last_execution_time,
       QueryStats.Execution_Count,
       QueryStats.DatabaseName,
       R.command,
       R.DBName,
       R.wait_type,
       R.wait_time,
       R.blocking_session_id,
       R.last_wait_type,
       R.wait_resource,
       R.open_transaction_count,
       R.open_resultset_count,
       R.querytext
FROM sys.dm_exec_sessions S
     LEFT OUTER JOIN ( SELECT ExC.session_id,
                              ExC.most_recent_sql_handle,
                              Max(ExC.client_net_address) AS IP_Address,
                              Min(ExC.connect_time) AS Connect_Time,
                              Max(ExC.last_read) AS Last_Read,
                              Max(ExC.last_write) AS Last_Write
                       FROM sys.dm_exec_connections ExC
                       GROUP BY session_id, most_recent_sql_handle ) AS C
       ON S.Session_ID = C.Session_ID
     LEFT OUTER JOIN V_Tuning_ExecRequests R
       ON S.Session_ID = R.Session_ID
     LEFT OUTER JOIN ( SELECT QS.total_worker_time / QS.execution_count AS Avg_CPU_Time,
                              SUBSTRING(st.text, (qs.statement_start_offset / 2) + 1, 
                                ((CASE qs.statement_end_offset
                                      WHEN - 1 THEN DATALENGTH(st.text)
                                      ELSE qs.statement_end_offset
                                  END - qs.statement_start_offset) / 2) + 1) AS SqlText,
                              QS.creation_time,
                              QS.last_execution_time,
                              QS.Execution_Count,
                              QS.sql_handle,
                              QS.plan_handle,
                              ST.DBID,
                              SD.Name AS DatabaseName,
                              ST.Encrypted
                       FROM sys.dm_exec_query_stats AS QS
                            CROSS APPLY sys.dm_exec_sql_text ( qs.sql_handle ) AS st
                                        LEFT OUTER JOIN sys.databases SD
                                          ON ST.DBID = SD.database_ID ) AS QueryStats
       ON QueryStats.Sql_Handle = C.most_recent_sql_handle
WHERE is_user_process <> 0

GO
