/****** Object:  View [dbo].[V_Index_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_Index_List
AS
SELECT tbl.name AS TableName, idx.name AS IndexName, 
    INDEX_COL(tbl.name, idx.indid, 1) AS col1, 
    INDEX_COL(tbl.name, idx.indid, 2) AS col2, 
    INDEX_COL(tbl.name, idx.indid, 3) AS col3, 
    INDEX_COL(tbl.name, idx.indid, 4) AS col4, 
    INDEX_COL(tbl.name, idx.indid, 5) AS col5, 
    INDEX_COL(tbl.name, idx.indid, 6) AS col6, idx.dpages, 
    idx.used, idx.rowcnt
FROM dbo.sysindexes idx INNER JOIN
    dbo.sysobjects tbl ON idx.id = tbl.id
WHERE (idx.indid > 0) AND (INDEXPROPERTY(tbl.id, idx.name, 
    'IsStatistics') = 0)


GO
