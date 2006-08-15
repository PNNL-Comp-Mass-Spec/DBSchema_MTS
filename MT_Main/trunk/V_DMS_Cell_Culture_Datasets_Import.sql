/****** Object:  View [dbo].[V_DMS_Cell_Culture_Datasets_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_DMS_Cell_Culture_Datasets_Import
AS
SELECT CellCulture, CellCultureID, DatasetID
FROM GIGASAX.DMS5.dbo.V_Export_Cell_Culture_Datasets T1

GO
