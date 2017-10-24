/****** Object:  View [dbo].[V_DMS_Campaign] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Campaign]
AS
SELECT Campaign, ID, Comment, Created
FROM S_V_Campaign_Detail_Report_Ex


GO
