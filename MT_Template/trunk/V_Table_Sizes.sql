/****** Object:  View [dbo].[V_Table_Sizes] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_Table_Sizes
AS
SELECT TOP 100 PERCENT su.tablename AS Table_Name, 
    ROUND((CONVERT(float, su.tablesize) * spt.low) 
    / (1024 * 1024), 3) AS Table_Size_MB
FROM master.dbo.spt_values spt CROSS JOIN
        (SELECT so.name tablename, SUM(si.reserved) 
           tablesize
      FROM sysobjects so JOIN
           sysindexes si ON so.id = si.id
      WHERE si.indid IN (0, 1, 255) AND so.xtype = 'U'
      GROUP BY so.name) su
WHERE (spt.number = 1) AND (spt.type = 'E')
ORDER BY su.tablesize DESC, su.tablename


GO
