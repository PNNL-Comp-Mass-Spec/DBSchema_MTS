SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Current_Activity_Text]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Current_Activity_Text]
GO

CREATE VIEW dbo.V_Current_Activity_Text
AS
SELECT CAST(T_Current_Activity.Database_Name AS char(28)) 
    AS [Database], 
    ISNULL(CAST(T_Current_Activity.Comment AS char(30)), '') 
    AS [Activity Synopsis], 
    ET_Minutes_Last24Hours AS [Duration (minutes)], 
    ISNULL(CAST(T_Current_Activity.Update_Began AS varchar(24)),
     '') AS Began, 
    ISNULL(CAST(T_Current_Activity.Update_Completed AS varchar(24)),
     '') AS Completed
FROM T_Current_Activity INNER JOIN
    T_MT_Database_List ON 
    T_Current_Activity.Database_ID = T_MT_Database_List.MTL_ID
WHERE (T_Current_Activity.Type = 'MT')
UNION
SELECT CAST(T_Current_Activity.Database_Name AS char(28)) 
    AS [Database], 
    ISNULL(CAST(T_Current_Activity.Comment AS char(30)), '') 
    AS [Activity Synopsis], 
    ET_Minutes_Last24Hours AS [Duration (minutes)], 
    ISNULL(CAST(T_Current_Activity.Update_Began AS varchar(24)),
     '') AS Began, 
    ISNULL(CAST(T_Current_Activity.Update_Completed AS varchar(24)),
     '') AS Completed
FROM T_Current_Activity INNER JOIN
    T_Peptide_Database_List ON 
    T_Current_Activity.Database_ID = T_Peptide_Database_List.PDB_ID
WHERE (T_Current_Activity.Type = 'PT')
UNION
SELECT CAST(T_Current_Activity.Database_Name AS char(28)) 
    AS [Database], 
    ISNULL(CAST(T_Current_Activity.Comment AS char(30)), '') 
    AS [Activity Synopsis], 
    ET_Minutes_Last24Hours AS [Duration (minutes)], 
    ISNULL(CAST(T_Current_Activity.Update_Began AS varchar(24)),
     '') AS Began, 
    ISNULL(CAST(T_Current_Activity.Update_Completed AS varchar(24)),
     '') AS Completed
FROM T_Current_Activity
WHERE (T_Current_Activity.Type = 'MSeq')

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

