/****** Object:  View [dbo].[V_DMS_Cell_Culture_Datasets_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Cell_Culture_Datasets_Import]
AS
SELECT CellCulture, CellCultureID, DatasetID
FROM S_V_Cell_Culture_Datasets


GO
