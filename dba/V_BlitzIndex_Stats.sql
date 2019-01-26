/****** Object:  View [dbo].[V_BlitzIndex_Stats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_BlitzIndex_Stats
AS
SELECT [database_name] AS DB,
       table_name,
       index_name,
       total_reads,
       user_updates,
       reads_per_write,
       index_usage_summary,
       total_singleton_lookup_count,
       total_range_scan_count,
       total_rows,
       avg_row_lock_wait_in_ms
FROM T_BlitzIndex_Results

GO
