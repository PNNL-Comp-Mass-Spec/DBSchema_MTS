/****** Object:  View [dbo].[V_General_Statistics_Report] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW dbo.V_General_Statistics_Report
AS
SELECT TOP 100 PERCENT category, label, value, sequence AS Entry_ID
FROM dbo.T_General_Statistics
ORDER BY sequence


GO
