/****** Object:  StoredProcedure [dbo].[sp_Sessions] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC dbo.sp_Sessions
AS

/**************************************************************************************************************
**  Purpose: 
**
**  Revision History  
**  
**  Date			Author					Version				Revision  
**  ----------		--------------------	-------------		-------------
**  05/28/2013		Michael Rounds			1.0					New Proc, complete rewrite and replacement for old sp_query. 
**																	Changes include displaying sessions with open transactions,new columns to output and SQL version specific logic
***************************************************************************************************************/
DECLARE @SQLVer NVARCHAR(20)

SELECT @SQLVer = LEFT(CONVERT(NVARCHAR(20),SERVERPROPERTY('productversion')),4)

IF CAST(@SQLVer AS NUMERIC(4,2)) < 11
BEGIN
		-- (SQL 2008R2 And Below)
	EXEC sp_executesql
	N'WITH SessionSQLText AS (
	SELECT
		r.session_id,
		r.total_elapsed_time,
		suser_name(r.user_id) as login_name,
		r.wait_time,
		r.last_wait_type,
		COALESCE(SUBSTRING(qt.[text],((r.statement_start_offset/2)+1),(LTRIM(LEN(CONVERT(NVARCHAR(MAX), qt.[text]))) * 2 - (r.statement_start_offset)/2)+1),'''') AS Formatted_SQL_Text,
		COALESCE(qt.[text],'''') AS Raw_SQL_Text,
		COALESCE(r.blocking_session_id,''0'',NULL) AS blocking_session_id,	
		r.[status],
		COALESCE(r.percent_complete,''0'',NULL) AS percent_complete,
		GETDATE() AS DateStamp
	FROM sys.dm_exec_requests r (nolock)
	CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) as qt
	WHERE r.session_id <> @@SPID
	)
	SELECT DISTINCT
		s.session_id,
		DB_Name(sp.dbid) AS DBName,
		CASE WHEN st.session_id = s.session_id THEN DATEDIFF(ss,at.transaction_begin_time,GETDATE()) ELSE (ssq.total_elapsed_time/1000.0) END as RunTime,
		CASE WHEN COALESCE(REPLACE(s.login_name,'' '',''''),'''') = '''' THEN ssq.login_name ELSE s.login_name END AS login_name,
		COALESCE(ssq.Formatted_SQL_Text,mrsh.[text]) AS Formatted_SQL_Text,
		COALESCE(ssq.Raw_SQL_Text,mrsh.[text]) AS Raw_SQL_Text,
		s.cpu_time,
		s.Logical_Reads,
		s.Reads,		
		s.Writes,
		ssq.wait_time,
		ssq.last_wait_type,
		CASE WHEN COALESCE(ssq.[status],'''') = '''' THEN s.[status] ELSE ssq.[status] END AS [status],
		CASE WHEN ssq.blocking_session_id = ''0'' THEN NULL ELSE ssq.blocking_session_id END AS blocking_session_id,		
		CASE WHEN st.session_id = s.session_id THEN (SELECT COUNT(*) FROM sys.dm_tran_session_transactions WHERE session_id = s.session_id) ELSE 0 END AS open_transaction_count,
		CASE WHEN ssq.percent_complete = ''0'' THEN NULL ELSE ssq.percent_complete END AS percent_complete,
		s.[Host_Name],
		ec.client_net_address,
		s.[Program_Name],
		s.last_request_start_time as start_time,
		s.login_time,
		GETDATE() AS DateStamp		
	INTO #TEMP
	FROM sys.dm_exec_sessions s (nolock)
	JOIN master..sysprocesses sp
		ON s.session_id = sp.spid
	LEFT OUTER
	JOIN SessionSQLText ssq (nolock) 
		ON ssq.session_id = s.session_id
	LEFT OUTER 
	JOIN sys.dm_tran_session_transactions st (nolock)
		ON st.session_id = s.session_id
	LEFT OUTER
	JOIN sys.dm_tran_active_transactions at (nolock)
		ON st.transaction_id = at.transaction_id
	LEFT OUTER
	JOIN sys.dm_tran_database_transactions dt
		ON at.transaction_id = dt.transaction_id	
	LEFT OUTER
	JOIN sys.dm_exec_connections ec
		ON s.session_id = ec.session_id
	CROSS APPLY sys.dm_exec_sql_text(ec.most_recent_sql_handle) as mrsh;
	WITH SessionInfo AS 
	(
	SELECT session_id,dbname,RunTime,login_name,Formatted_SQL_Text,Raw_SQL_Text,cpu_time,
		logical_reads,reads,writes,wait_time,last_wait_type,[status],blocking_session_id,open_transaction_count,percent_complete,[host_name],client_net_address,
		[program_name],start_time,login_time,datestamp,ROW_NUMBER() OVER (ORDER BY session_id) AS RowNumber
		FROM #TEMP
	)
	SELECT session_id,dbname,RunTime,login_name,Formatted_SQL_Text,Raw_SQL_Text,cpu_time,
		logical_reads,reads,writes,wait_time,last_wait_type,[status],blocking_session_id,open_transaction_count,percent_complete,[host_name],client_net_address,
		[program_name],start_time,login_time,datestamp
	FROM SessionInfo WHERE RowNumber IN (SELECT MIN(RowNumber) FROM SessionInfo GROUP BY session_id)
	AND session_id > 50 
	AND session_id <> @@SPID
	AND RunTime IS NOT NULL
	ORDER BY session_id;

	DROP TABLE #TEMP;'	
END
ELSE BEGIN
		-- (SQL 2012 And Above)
	EXEC sp_executesql
	N'WITH SessionSQLText AS (
	SELECT
		r.session_id,
		r.total_elapsed_time,
		suser_name(r.user_id) as login_name,
		r.wait_time,
		r.last_wait_type,		
		COALESCE(SUBSTRING(qt.[text],((r.statement_start_offset/2)+1),(LTRIM(LEN(CONVERT(NVARCHAR(MAX), qt.[text]))) * 2 - (r.statement_start_offset)/2)+1),'''') AS Formatted_SQL_Text,
		COALESCE(qt.[text],'''') AS Raw_SQL_Text,
		COALESCE(r.blocking_session_id,''0'',NULL) AS blocking_session_id,	
		r.[status],
		COALESCE(r.percent_complete,''0'',NULL) AS percent_complete,
		GETDATE() AS DateStamp
	FROM sys.dm_exec_requests r (nolock)
	CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) as qt
	WHERE r.session_id <> @@SPID
	)
	SELECT DISTINCT
		s.session_id,
		DB_Name(s.database_id) AS DBName,
		CASE WHEN st.session_id = s.session_id THEN DATEDIFF(ss,at.transaction_begin_time,GETDATE()) ELSE (ssq.total_elapsed_time/1000.0) END as RunTime,
		CASE WHEN COALESCE(REPLACE(s.login_name,'' '',''''),'''') = '''' THEN ssq.login_name ELSE s.login_name END AS login_name,
		COALESCE(ssq.Formatted_SQL_Text,mrsh.[text]) AS Formatted_SQL_Text,
		COALESCE(ssq.Raw_SQL_Text,mrsh.[text]) AS Raw_SQL_Text,
		s.cpu_time,
		s.Logical_Reads,
		s.Reads,		
		s.Writes,
		ssq.wait_time,
		ssq.last_wait_type,		
		CASE WHEN COALESCE(ssq.[status],'''') = '''' THEN s.[status] ELSE ssq.[status] END AS [status],
		CASE WHEN ssq.blocking_session_id = ''0'' THEN NULL ELSE ssq.blocking_session_id END AS blocking_session_id,
		s.open_transaction_count,
		CASE WHEN ssq.percent_complete = ''0'' THEN NULL ELSE ssq.percent_complete END AS percent_complete,
		s.[Host_Name],
		ec.client_net_address,
		s.[Program_Name],
		s.last_request_start_time as start_time,
		s.login_time,
		GETDATE() AS DateStamp		
	INTO #TEMP
	FROM sys.dm_exec_sessions s (nolock)
	LEFT OUTER
	JOIN SessionSQLText ssq (nolock) 
		ON ssq.session_id = s.session_id
	LEFT OUTER 
	JOIN sys.dm_tran_session_transactions st (nolock)
		ON st.session_id = s.session_id
	LEFT OUTER
	JOIN sys.dm_tran_active_transactions at (nolock)
		ON st.transaction_id = at.transaction_id
	LEFT OUTER
	JOIN sys.dm_tran_database_transactions dt
		ON at.transaction_id = dt.transaction_id	
	LEFT OUTER
	JOIN sys.dm_exec_connections ec
		ON s.session_id = ec.session_id
	CROSS APPLY sys.dm_exec_sql_text(ec.most_recent_sql_handle) as mrsh;
	WITH SessionInfo AS 
	(
	SELECT session_id,dbname,RunTime,login_name,Formatted_SQL_Text,Raw_SQL_Text,cpu_time,
		logical_reads,reads,writes,wait_time,last_wait_type,[status],blocking_session_id,open_transaction_count,percent_complete,[host_name],client_net_address,
		[program_name],start_time,login_time,datestamp,ROW_NUMBER() OVER (ORDER BY session_id) AS RowNumber
		FROM #TEMP
	)
	SELECT session_id,dbname,RunTime,login_name,Formatted_SQL_Text,Raw_SQL_Text,cpu_time,
		logical_reads,reads,writes,wait_time,last_wait_type,[status],blocking_session_id,open_transaction_count,percent_complete,[host_name],client_net_address,
		[program_name],start_time,login_time,datestamp
	FROM SessionInfo WHERE RowNumber IN (SELECT MIN(RowNumber) FROM SessionInfo GROUP BY session_id)
	AND session_id > 50 
	AND session_id <> @@SPID
	AND RunTime IS NOT NULL
	ORDER BY session_id;
	DROP TABLE #TEMP;'
END

GO
