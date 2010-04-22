/****** Object:  View [dbo].[V_Tuning_MissingIndices] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE VIEW dbo.V_Tuning_MissingIndices
AS
SELECT sys.objects.name,
       (avg_total_user_cost * avg_user_impact) * (user_seeks + user_scans) AS Impact,
       'CREATE NONCLUSTERED INDEX IX_' + sys.objects.name + '_IndexName ON ' + sys.objects.name + ' ( ' +
          IsNull(IndexDetails.equality_columns, '') + 
          CASE
          WHEN IndexDetails.inequality_columns IS NULL THEN ''
          ELSE CASE
               WHEN IndexDetails.equality_columns IS NULL THEN ''
               ELSE ','
               END + IndexDetails.inequality_columns
          END + ' ) ' + 
          CASE
          WHEN IndexDetails.included_columns IS NULL THEN ''
          ELSE 'INCLUDE (' + IndexDetails.included_columns + ')'
          END + ';' AS CreateIndexStatement,
       IndexDetails.equality_columns,
       IndexDetails.inequality_columns,
       IndexDetails.included_columns
FROM sys.dm_db_missing_index_group_stats AS IndexGrpStats
     INNER JOIN sys.dm_db_missing_index_groups AS IndexGroups
       ON IndexGrpStats.group_handle = IndexGroups.index_group_handle
     INNER JOIN sys.dm_db_missing_index_details AS IndexDetails
       ON IndexGroups.index_handle = IndexDetails.index_handle
     INNER JOIN sys.objects WITH ( nolock )
       ON IndexDetails.OBJECT_ID = sys.objects.OBJECT_ID
WHERE (IndexGrpStats.group_handle IN (
		SELECT TOP ( 500 ) group_handle
		FROM sys.dm_db_missing_index_group_stats WITH ( nolock )
		ORDER BY (avg_total_user_cost * avg_user_impact) 
			   * (user_seeks + user_scans) DESC )
       ) AND
      OBJECTPROPERTY(sys.objects.OBJECT_ID, 'isusertable') = 1
--ORDER BY 2 DESC, 3 DESC


GO
