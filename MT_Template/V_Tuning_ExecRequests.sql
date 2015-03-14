/****** Object:  View [dbo].[V_Tuning_ExecRequests] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE VIEW dbo.V_Tuning_ExecRequests
AS
WITH ExecRequests ( session_id, request_id, start_time, status, command, DBName, wait_type, 
       wait_time, blocking_session_id, last_wait_type, wait_resource, open_transaction_count, 
       open_resultset_count, database_id, user_id, connection_id, transaction_id, sql_handle, 
       statement_start_offset, statement_end_offset, plan_handle )
AS
( SELECT DER.session_id,
         DER.request_id,
         DER.start_time,
         DER.status,
         DER.command,
         SD.Name AS DBName,
         DER.wait_type,
         DER.wait_time,
         DER.blocking_session_id,
         DER.last_wait_type,
         DER.wait_resource,
         DER.open_transaction_count,
         DER.open_resultset_count,
         DER.database_id,
         DER.user_id,
         DER.connection_id,
         DER.transaction_id,
         DER.sql_handle,
         DER.statement_start_offset,
         DER.statement_end_offset,
         DER.plan_handle
  FROM sys.dm_exec_requests DER
       INNER JOIN sys.databases SD
         ON DER.database_id = SD.database_id )
SELECT '' AS QueryText,
       ExecRequests.*
FROM ExecRequests
WHERE ExecRequests.sql_handle IS NULL
UNION
SELECT s2.text AS QueryText,
       ExecRequests.*
FROM ExecRequests
     CROSS APPLY sys.dm_exec_sql_text ( ExecRequests.sql_handle ) AS s2
WHERE NOT ExecRequests.sql_handle IS NULL


GO
GRANT VIEW DEFINITION ON [dbo].[V_Tuning_ExecRequests] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_Tuning_ExecRequests] TO [MTS_DB_Lite] AS [dbo]
GO
