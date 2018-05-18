/****** Object:  View [dbo].[BlitzFirst_PerfmonStats2_Actuals] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[BlitzFirst_PerfmonStats2_Actuals] AS 
WITH PERF_AVERAGE_BULK AS
(
    SELECT ServerName,
           object_name,
           instance_name,
           counter_name,
           CASE WHEN CHARINDEX('(', counter_name) = 0 THEN counter_name ELSE LEFT (counter_name, CHARINDEX('(',counter_name)-1) END    AS   counter_join,
           CheckDate,
           cntr_delta
    FROM   [dbo].[BlitzFirst_PerfmonStats2_Deltas]
    WHERE  cntr_type IN(1073874176)
    AND cntr_delta <> 0
),
PERF_LARGE_RAW_BASE AS
(
    SELECT ServerName,
           object_name,
           instance_name,
           LEFT(counter_name, CHARINDEX('BASE', UPPER(counter_name))-1) AS counter_join,
           CheckDate,
           cntr_delta
    FROM   [dbo].[BlitzFirst_PerfmonStats2_Deltas]
    WHERE  cntr_type IN(1073939712)
    AND cntr_delta <> 0
),
PERF_AVERAGE_FRACTION AS
(
    SELECT ServerName,
           object_name,
           instance_name,
           counter_name,
           counter_name AS counter_join,
           CheckDate,
           cntr_delta
    FROM   [dbo].[BlitzFirst_PerfmonStats2_Deltas]
    WHERE  cntr_type IN(537003264)
    AND cntr_delta <> 0
),
PERF_COUNTER_BULK_COUNT AS
(
    SELECT ServerName,
           object_name,
           instance_name,
           counter_name,
           CheckDate,
           cntr_delta / ElapsedSeconds AS cntr_value
    FROM   [dbo].[BlitzFirst_PerfmonStats2_Deltas]
    WHERE  cntr_type IN(272696576, 272696320)
    AND cntr_delta <> 0
),
PERF_COUNTER_RAWCOUNT AS
(
    SELECT ServerName,
           object_name,
           instance_name,
           counter_name,
           CheckDate,
           cntr_value
    FROM   [dbo].[BlitzFirst_PerfmonStats2_Deltas]
    WHERE  cntr_type IN(65792, 65536)
)

SELECT NUM.ServerName,
       NUM.object_name,
       NUM.counter_name,
       NUM.instance_name,
       NUM.CheckDate,
       NUM.cntr_delta / DEN.cntr_delta AS cntr_value
       
FROM   PERF_AVERAGE_BULK AS NUM
       JOIN PERF_LARGE_RAW_BASE AS DEN ON NUM.counter_join = DEN.counter_join
                                          AND NUM.CheckDate = DEN.CheckDate
                                          AND NUM.ServerName = DEN.ServerName
                                          AND NUM.object_name = DEN.object_name
                                          AND NUM.instance_name = DEN.instance_name
                                          AND DEN.cntr_delta <> 0

UNION ALL

SELECT NUM.ServerName,
       NUM.object_name,
       NUM.counter_name,
       NUM.instance_name,
       NUM.CheckDate,
       CAST((CAST(NUM.cntr_delta as DECIMAL(19)) / DEN.cntr_delta) as decimal(23,3))  AS cntr_value
FROM   PERF_AVERAGE_FRACTION AS NUM
       JOIN PERF_LARGE_RAW_BASE AS DEN ON NUM.counter_join = DEN.counter_join
                                          AND NUM.CheckDate = DEN.CheckDate
                                          AND NUM.ServerName = DEN.ServerName
                                          AND NUM.object_name = DEN.object_name
                                          AND NUM.instance_name = DEN.instance_name
                                          AND DEN.cntr_delta <> 0
UNION ALL

SELECT ServerName,
       object_name,
       counter_name,
       instance_name,
       CheckDate,
       cntr_value
FROM   PERF_COUNTER_BULK_COUNT

UNION ALL

SELECT ServerName,
       object_name,
       counter_name,
       instance_name,
       CheckDate,
       cntr_value
FROM   PERF_COUNTER_RAWCOUNT;
GO
