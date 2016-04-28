/****** Object:  View [dbo].[V_DMS_Data_Package_Jobs_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create VIEW V_DMS_Data_Package_Jobs_Import
AS
SELECT t1.Data_Package_ID,
       t1.Job,
       t1.Dataset,
       t1.Tool,
       t1.[Package Comment] AS Package_Comment,
       t1.[Item Added] AS Item_Added
FROM GIGASAX.DMS_Data_Package.dbo.V_Data_Package_Analysis_Jobs_Export t1

GO
