/****** Object:  View [dbo].[V_DMS_Analysis_Job_Import_Storage_Path] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Analysis_Job_Import_Storage_Path]
AS
select T1.Job,
       T1.Dataset,
       T1.StoragePathClient,
       T1.StoragePathServer,
       T1.DatasetFolder,
       T1.ResultsFolder
from GIGASAX.DMS5.dbo.V_Analysis_Job_Export_Storage_Path AS T1


GO
