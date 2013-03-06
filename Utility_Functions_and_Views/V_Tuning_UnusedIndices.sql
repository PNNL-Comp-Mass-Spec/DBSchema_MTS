ALTER VIEW [dbo].[V_Tuning_UnusedIndices]
AS
	-- Note: Stats from sys.dm_db_index_usage_stats are as-of the last time the Database started up
	-- Thus, make sure the database has been running for a while before you consider deleting an apparently unused index
SELECT OBJECT_NAME(i.[object_id]) AS Table_Name,
       CASE i.[index_id]
           WHEN 0 THEN N'HEAP'
           ELSE i.[name]
       END AS Index_Name,
       i.index_id AS Index_ID,
       IdxSizes.Space_Reserved_MB,
       IdxSizes.Space_Used_MB,
       IdxSizes.Index_Row_Count,
       IdxSizes.Table_Row_Count
FROM sys.indexes AS i
     INNER JOIN sys.objects AS o
       ON i.[object_id] = o.[object_id]
     LEFT OUTER JOIN V_Table_Index_Sizes AS IdxSizes
       ON i.[name] = IdxSizes.Index_Name
WHERE NOT EXISTS ( SELECT *
                   FROM sys.dm_db_index_usage_stats AS u
                   WHERE u.[object_id] = i.[object_id] AND
                         u.[index_id] = i.[index_id] AND
                         [database_id] = DB_ID() ) AND
      OBJECTPROPERTY(i.[object_id], 'IsUserTable') = 1

GO

GRANT VIEW DEFINITION ON [dbo].[V_Tuning_UnusedIndices] TO [PNL\D3M578] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[V_Tuning_UnusedIndices] TO [PNL\D3M580] AS [dbo]
GO


