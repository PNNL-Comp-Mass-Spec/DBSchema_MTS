CREATE VIEW dbo.V_Tuning_QueryExecutionStats_WithPlanStats
AS
SELECT QES.*,
       CP.RefCounts AS Plan_RefCount,
       CP.UseCounts AS Plan_UseCount,
       CP.CacheObjType AS Plan_CacheObjType,
       CP.ObjType AS Plan_ObjType,
       QP.query_plan
FROM V_Tuning_QueryExecutionStats QES
     INNER JOIN sys.dm_exec_cached_plans AS CP WITH ( NoLock )
       ON QES.plan_handle = CP.plan_handle
     CROSS APPLY sys.dm_exec_query_plan ( QES.plan_handle ) QP
GO

-- select top 5 * from V_Tuning_QueryExecutionStats_WithPlanStats order by total_worker_time_sec desc
-- select top 5 * from V_Tuning_QueryExecutionStats order by total_worker_time_sec desc


