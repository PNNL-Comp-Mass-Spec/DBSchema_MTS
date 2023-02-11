/****** Object:  View [dbo].[V_DMS_Campaign_Cell_Culture_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Campaign_Cell_Culture_Import]
AS
SELECT Campaign, CellCulture, CC_ID
FROM S_V_Campaign_Cell_Culture


GO
