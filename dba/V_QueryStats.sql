/****** Object:  View [dbo].[V_QueryStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[V_QueryStats] 
As 
(
	SELECT QS.Entry_ID,
	       QS.interval_start,
	       QS.interval_end,
	       SUBSTRING(QT.QueryText, QS.statement_start_offset / 2 + 1, 
	         (CASE
	              WHEN (QS.statement_end_offset = -1) THEN LEN(QT.QueryText) * 2
	              ELSE QS.statement_end_offset
	          END - QS.statement_start_offset) / 2 + 1) AS Sql_Stmt,
	       QS.execution_count,
	       QS.total_elapsed_time_ms,
	       QS.min_elapsed_time_ms,
	       QS.max_elapsed_time_ms,
	       QS.total_worker_time_ms,
	       QS.min_worker_time_ms,
	       QS.max_worker_time_ms,
	       QS.total_logical_reads,
	       QS.min_logical_reads,
	       QS.max_logical_reads,
	       QS.total_physical_reads,
	       QS.min_physical_reads,
	       QS.max_physical_reads,
	       QS.total_logical_writes,
	       QS.min_logical_writes,
	       QS.max_logical_writes,
	       QS.creation_time,
	       QS.last_execution_time,
	       QS.sql_handle,
	       QS.plan_handle,
	       QS.statement_start_offset,
	       QS.statement_end_offset
	FROM T_QueryStats QS Inner Join T_QueryText QT On QS.sql_handle = QT.sql_handle

)



GO
