/****** Object:  View [dbo].[V_Cell_Culture_Datasets_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create view V_Cell_Culture_Datasets_Import
AS
SELECT CellCulture, CellCultureID, DatasetID
FROM Gigasax.DMS5.dbo.V_Export_Cell_Culture_Datasets


GO
