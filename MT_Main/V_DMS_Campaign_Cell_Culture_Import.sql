/****** Object:  View [dbo].[V_DMS_Campaign_Cell_Culture_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_DMS_Campaign_Cell_Culture_Import
AS
SELECT Campaign, CellCulture, CC_ID
FROM GIGASAX.DMS5.dbo.V_Export_Campaign_Cell_Culture t1

GO
