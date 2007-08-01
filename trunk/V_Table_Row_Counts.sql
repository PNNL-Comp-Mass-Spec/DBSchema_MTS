/****** Object:  View [dbo].[V_Table_Row_Counts] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_Table_Row_Counts
AS
SELECT TOP 100 PERCENT o.name AS TableName, 
    i.rowcnt AS TableRowCount
FROM dbo.sysobjects o INNER JOIN
    dbo.sysindexes i ON o.id = i.id
WHERE (o.type = 'u') AND (i.indid < 2) AND 
    (o.name <> 'dtproperties')
ORDER BY o.name


GO
