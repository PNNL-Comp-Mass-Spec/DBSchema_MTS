SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Index_List_Overlapping]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Index_List_Overlapping]
GO

create VIEW dbo.V_Index_List_Overlapping
AS
SELECT TOP 100 PERCENT l1.TableName, l1.IndexName, 
    l2.IndexName AS overlappingIndex, l1.col1, l1.col2, l1.col3, 
    l1.col4, l1.col5, l1.col6, l1.dpages, l1.used, l1.rowcnt
FROM dbo.V_Index_List l1 INNER JOIN
    dbo.V_Index_List l2 ON l1.TableName = l2.TableName AND 
    l1.IndexName <> l2.IndexName AND l1.col1 = l2.col1 AND 
    (l1.col2 IS NULL OR
    l2.col2 IS NULL OR
    l1.col2 = l2.col2) AND (l1.col3 IS NULL OR
    l2.col3 IS NULL OR
    l1.col3 = l2.col3) AND (l1.col4 IS NULL OR
    l2.col4 IS NULL OR
    l1.col4 = l2.col4) AND (l1.col5 IS NULL OR
    l2.col5 IS NULL OR
    l1.col5 = l2.col5) AND (l1.col6 IS NULL OR
    l2.col6 IS NULL OR
    l1.col6 = l2.col6)
ORDER BY l1.TableName, l1.IndexName

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

