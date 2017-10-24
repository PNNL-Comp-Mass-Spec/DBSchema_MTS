/****** Object:  View [dbo].[V_DMS_Data_Package_Jobs_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[V_DMS_Data_Package_Jobs_Import]
AS
SELECT Data_Package_ID,
       Job,
       Dataset,
       Tool,
       [Package Comment] AS Package_Comment,
       [Item Added] AS Item_Added
FROM S_V_Data_Package_Analysis_Jobs


GO
