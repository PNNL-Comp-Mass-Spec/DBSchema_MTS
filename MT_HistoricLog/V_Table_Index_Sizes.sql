/****** Object:  View [dbo].[V_Table_Index_Sizes] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_Table_Index_Sizes]
AS
WITH Table_Space_Usage
( Schema_Name, Table_Name, Index_Name, Space_Used_KB, Space_Reserved_KB, Index_Row_Count, Table_Row_Count, fill_factor, is_disabled )
AS (
 SELECT  s.Name,
         o.Name,
         COALESCE (i.Name, 'HEAP'),
         p.used_page_count * 8,
         p.reserved_page_count * 8,
         CASE WHEN i.index_id IN ( 0, 1 ) THEN p.row_count ELSE 0 END,
         p.row_count,
         i.fill_factor,
         i.is_disabled
 FROM sys.dm_db_partition_stats p
	INNER JOIN sys.objects o ON o.object_id = p.object_id
	INNER JOIN sys.schemas s ON s.schema_id = o.schema_id
	LEFT OUTER JOIN sys.indexes i ON i.object_id = p.object_id AND i.index_id = p.index_id
 WHERE o.type_desc = 'USER_TABLE' AND o.is_ms_shipped = 0
)
 SELECT TOP 100 PERCENT
        t.Schema_Name, t.Table_Name, t.Index_Name,
        SUM(t.Space_Used_KB) / 1024.0 AS Space_Used_MB,
        SUM(t.Space_Reserved_KB) / 1024.0 AS Space_Reserved_MB,
        SUM(t.Index_Row_Count) AS Index_Row_Count,
        SUM(t.Table_Row_Count) AS Table_Row_Count,
        fill_factor,
        is_disabled
 FROM Table_Space_Usage as t
 GROUP BY t.Schema_Name, t.Table_Name, t.Index_Name,fill_factor, is_disabled
 ORDER BY t.Schema_Name, t.Table_Name, t.Index_Name


GO
