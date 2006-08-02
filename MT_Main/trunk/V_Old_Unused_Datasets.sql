SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Old_Unused_Datasets]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Old_Unused_Datasets]
GO

CREATE VIEW dbo.V_Old_Unused_Datasets
AS
SELECT *
FROM (SELECT DDR.Instrument, DDR.Organism, DDR.Dataset, 
          ISNULL(DDR.[Acquisition Start], DDR.Created) 
          AS Acquisition_Time, DatasetQ.Last_Affected_Max, 
          DatasetQ.Server_Count, DatasetQ.Job_Count
      FROM (SELECT DAJI.Dataset, MAX(LookupQ.Last_Affected) 
                AS Last_Affected_Max, 
                COUNT(DISTINCT LookupQ.Server) 
                AS Server_Count, 
                COUNT(DISTINCT LookupQ.Job) 
                AS Job_Count
            FROM (SELECT @@ServerName AS Server, Job, 
                      Last_Affected
                  FROM T_Analysis_Job_to_MT_DB_Map AJMDM
                  UNION
                  SELECT 'Pogo' AS Server, Job, 
                      Last_Affected
                  FROM Pogo.MT_Main.dbo.T_Analysis_Job_to_MT_DB_Map)
                 LookupQ INNER JOIN
                dbo.V_DMS_Analysis_Job_Import_Ex DAJI ON 
                LookupQ.Job = DAJI.Job
            GROUP BY DAJI.Dataset) 
          DatasetQ RIGHT OUTER JOIN
          dbo.V_DMS_Dataset_Detail_Report DDR ON 
          DatasetQ.Dataset COLLATE SQL_Latin1_General_CP1_CI_AS
           = DDR.Dataset) OuterQ
WHERE (ISNULL(Last_Affected_Max, Acquisition_Time) 
    < DATEADD(month, - 18, GETDATE()))

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

