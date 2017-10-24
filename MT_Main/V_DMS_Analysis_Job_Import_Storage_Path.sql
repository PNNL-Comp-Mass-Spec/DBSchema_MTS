/****** Object:  View [dbo].[V_DMS_Analysis_Job_Import_Storage_Path] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Analysis_Job_Import_Storage_Path]
AS
SELECT Job,
       Dataset,
       StoragePathClient,
       StoragePathServer,
       DatasetFolder,
       ResultsFolder
FROM S_V_Analysis_Job_Storage_Path


GO
