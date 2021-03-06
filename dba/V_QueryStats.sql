/****** Object:  View [dbo].[V_QueryStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_QueryStats 
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
	       Cast(total_elapsed_time_ms / 1000.0 / execution_count AS decimal(9, 2)) AS Avg_elapsed_time_sec,
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
	FROM T_QueryStats QS
	     INNER JOIN T_QueryText QT
	       ON QS.sql_handle = QT.sql_handle

)

GO
