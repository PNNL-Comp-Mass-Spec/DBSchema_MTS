/****** Object:  View [dbo].[V_Current_Activity_Email] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Current_Activity_Email
AS
SELECT TOP 100 PERCENT Database_Name AS [Database], 
    Comment AS [Activity Synopsis], CONVERT(int, 
    ROUND(ET_Minutes_Last24Hours, 0)) AS [Duration (minutes)], 
    Update_Began AS Began, 
    Update_Completed AS Completed
FROM dbo.T_Current_Activity
ORDER BY Database_Name

GO
