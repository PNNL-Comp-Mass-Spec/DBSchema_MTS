/****** Object:  View [dbo].[V_Cell_Culture_Datasets_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE view [dbo].[V_Cell_Culture_Datasets_Import]
AS
SELECT Biomaterial AS CellCulture, Biomaterial_ID AS CellCultureID, Dataset_ID AS DatasetID
FROM Gigasax.DMS5.dbo.V_Export_Biomaterial_Datasets


GO
