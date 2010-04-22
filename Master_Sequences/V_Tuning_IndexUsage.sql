/****** Object:  View [dbo].[V_Tuning_IndexUsage] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE VIEW [dbo].[V_Tuning_IndexUsage]
AS
	/*
	** Types of data returned:
	** Scans: These occur when the access method never attempts to use the index in a typical B-Tree operation (e.g., a Seek). In other words, it will read all the pages in the order it deems appropriate unless theres a limiting clause (e.g., TOP, ROWCOUNT). 
	** Seeks: These occur when the B-Tree or index is used to fetch one or more rows. This might also include range scans that start their process with a Seek. 
	** Lookups: These occur when an index or heap is accessed via a non-clustered index to retrieve extra columns not present in the non-clustered index to satisfy the Select list. These are commonly referred to as BookMark Lookup operations. 
	** Updates: These occur whenever theres an Insert, Update, or Delete (i.e., not just Updates). 
	*/
	-- Note: Stats from sys.dm_db_index_usage_stats are as-of the last time the Database started up
	-- Thus, make sure the database has been running for a while before you consider deleting an apparently unused index
SELECT O.Name AS Table_Name,
       I.Name AS Index_Name,
       S.Index_ID,
       S.User_Seeks,       S.User_Scans,       S.User_Lookups,       S.User_Updates,
       S.Last_User_Seek,   S.Last_User_Scan,   S.Last_User_Lookup,   S.Last_User_Update,
       S.System_Seeks,     S.System_Scans,     S.System_Lookups,     S.System_Updates,
       S.Last_System_Seek, S.Last_System_Scan, S.Last_System_Lookup, S.Last_System_Update
FROM sys.dm_db_index_usage_stats S
     INNER JOIN sys.objects O
       ON S.Object_ID = O.Object_ID
     INNER JOIN sys.indexes I
       ON O.Object_ID = I.Object_ID AND
          S.Index_ID = I.Index_ID
WHERE S.[database_id] = DB_ID() 

GO
