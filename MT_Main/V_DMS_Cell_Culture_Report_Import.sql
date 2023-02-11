/****** Object:  View [dbo].[V_DMS_Cell_Culture_Report_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Cell_Culture_Report_Import]
AS
SELECT Name AS CellCulture, Source, Contact, Type, Reason, 
    Created, PI, Comment, Campaign, [#ID] AS CellCultureID
FROM S_V_Cell_Culture_Report


GO
