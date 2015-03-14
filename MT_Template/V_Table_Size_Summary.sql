/****** Object:  View [dbo].[V_Table_Size_Summary] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE VIEW dbo.V_Table_Size_Summary
AS
WITH Table_Space_Summary
(Schema_Name, Table_Name, Space_Used_MB, Space_Reserved_MB, Table_Row_Count)
AS
(
 SELECT Schema_Name, Table_Name, 
       	SUM(Space_Used_MB), 
		SUM(Space_Reserved_MB), 
		MAX(Table_Row_Count)
 FROM dbo.V_Table_Index_Sizes
 GROUP BY Schema_Name, Table_Name
)
SELECT TOP 100 PERCENT S.Schema_Name, S.Table_Name,
	S.Space_Used_MB,
    ROUND(S.Space_Used_MB / CONVERT(real, TotalsQ.TotalUsedMB) * 100, 2) AS Percent_Total_Used_MB, 
	S.Space_Reserved_MB,
    ROUND(S.Space_Reserved_MB / CONVERT(real, TotalsQ.TotalReservedMB) * 100, 2) AS Percent_Total_Reserved_MB, 
    S.Table_Row_Count, 
    ROUND(S.Table_Row_Count / CONVERT(real, TotalsQ.TotalRows) * 100, 2) AS Percent_Total_Rows
FROM Table_Space_Summary S CROSS JOIN
        (SELECT SUM(Space_Used_MB) AS TotalUsedMB,
				SUM(Space_Reserved_MB) AS TotalReservedMB,
				SUM(Table_Row_Count) AS TotalRows
		 FROM Table_Space_Summary) TotalsQ
ORDER BY S.Space_Used_MB DESC

GO
GRANT VIEW DEFINITION ON [dbo].[V_Table_Size_Summary] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_Table_Size_Summary] TO [MTS_DB_Lite] AS [dbo]
GO
