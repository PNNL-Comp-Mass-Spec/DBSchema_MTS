/****** Object:  View [dbo].[V_Tuning_UnusedIndices] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE VIEW [dbo].[V_Tuning_UnusedIndices]
AS
	-- Note: Stats from sys.dm_db_index_usage_stats are as-of the last time the Database started up
	-- Thus, make sure the database has been running for a while before you consider deleting an apparently unused index
SELECT OBJECT_NAME(i.[object_id]) AS Table_Name,
       CASE i.[index_id]
           WHEN 0 THEN N'HEAP'
           ELSE i.[name]
       END AS Index_Name,
       i.index_id AS Index_ID
FROM sys.indexes AS i
     INNER JOIN sys.objects AS o
       ON i.[object_id] = o.[object_id]
WHERE NOT EXISTS ( SELECT *
                   FROM sys.dm_db_index_usage_stats AS u
                   WHERE u.[object_id] = i.[object_id] AND
                         u.[index_id] = i.[index_id] AND
                         [database_id] = DB_ID() ) AND
      OBJECTPROPERTY(i.[object_id], 'IsUserTable') = 1

GO
