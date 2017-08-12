/****** Object:  View [dbo].[V_Tuning_Database_Access_Stats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_Tuning_Database_Access_Stats
AS
WITH agg AS (
	SELECT d.name DB,
	       s.last_user_seek,
	       s.last_user_scan,
	       s.last_user_lookup,
	       s.last_user_update
	FROM sys.dm_db_index_usage_stats s
	     INNER JOIN sys.databases d
	       ON s.database_id = d.database_id
)
SELECT @@SERVERNAME AS [Server],
       DB AS [DATABASE],
       last_read = MAX(last_read),
       last_write = MAX(last_write)
FROM (
	SELECT DB, last_user_seek, NULL FROM agg
	UNION ALL
	SELECT DB, last_user_scan, NULL FROM agg
	UNION ALL
	SELECT DB, last_user_lookup, NULL FROM agg
	UNION ALL
	SELECT DB, NULL, last_user_update FROM agg
	) AS x(DB, last_read, last_write)
GROUP BY DB;


GO
