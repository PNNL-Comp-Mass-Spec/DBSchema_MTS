SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Current_Activity]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Current_Activity]
GO

CREATE VIEW dbo.V_Current_Activity
AS
SELECT TOP 100 PERCENT *
FROM (SELECT CA.Database_Name AS Name, CA.Type, 
          'Cam: ' + T_MT_Database_List.MTL_Campaign AS Association,
           T_MT_Database_State_Name.Name AS State, 
          T_Update_State_Name.Name AS [Update], 
          CA.Update_Began AS Began, 
          CA.Update_Completed AS Completed, CA.Comment, 
          Round(DateDiff(second, CA.Update_Began, 
          CASE WHEN CA.Update_Completed IS NULL AND 
          CA.Update_State = 2 THEN GetDate() 
          ELSE CA.Update_Completed END) 
          / 60.0 - Pause_Length_Minutes, 1) 
          AS [Duration Last Cycle (Minutes)], 
          CA.Pause_Length_Minutes, 
          ET_Minutes_Last24Hours AS [Duration Last 24 hours], 
          ET_Minutes_Last7Days AS [Duration Last 7 Days]
      FROM T_Current_Activity CA INNER JOIN
          T_MT_Database_List ON 
          CA.Database_ID = T_MT_Database_List.MTL_ID INNER JOIN
          T_MT_Database_State_Name ON 
          T_MT_Database_List.MTL_State = T_MT_Database_State_Name.ID
           INNER JOIN
          T_Update_State_Name ON 
          CA.Update_State = T_Update_State_Name.ID
      WHERE (CA.Type = 'MT')
      UNION
      SELECT CA.Database_Name AS Name, CA.Type, 
          'Org: ' + T_Peptide_Database_List.PDB_Organism AS Association,
           T_MT_Database_State_Name.Name AS State, 
          T_Update_State_Name.Name AS [Update], 
          CA.Update_Began AS Began, 
          CA.Update_Completed AS Completed, CA.Comment, 
          Round(DateDiff(second, CA.Update_Began, 
          CASE WHEN CA.Update_Completed IS NULL AND 
          CA.Update_State = 2 THEN GetDate() 
          ELSE CA.Update_Completed END) 
          / 60.0 - Pause_Length_Minutes, 1) 
          AS [Duration Last Cycle (Minutes)], 
          CA.Pause_Length_Minutes, 
          ET_Minutes_Last24Hours AS [Duration Last 24 hours], 
          ET_Minutes_Last7Days AS [Duration Last 7 Days]
      FROM T_Current_Activity AS CA INNER JOIN
          T_Peptide_Database_List ON 
          CA.Database_ID = T_Peptide_Database_List.PDB_ID INNER
           JOIN
          T_MT_Database_State_Name ON 
          T_Peptide_Database_List.PDB_State = T_MT_Database_State_Name.ID
           INNER JOIN
          T_Update_State_Name ON 
          CA.Update_State = T_Update_State_Name.ID
      WHERE (CA.Type = 'PT')
      UNION
      SELECT CA.Database_Name AS Name, CA.Type, 
          'Master Sequences' AS Association, 
          T_MT_Database_State_Name.Name AS State, 
          T_Update_State_Name.Name AS [Update], 
          CA.Update_Began AS Began, 
          CA.Update_Completed AS Completed, CA.Comment, 
          Round(DateDiff(second, CA.Update_Began, 
          CASE WHEN CA.Update_Completed IS NULL AND 
          CA.Update_State = 2 THEN GetDate() 
          ELSE CA.Update_Completed END) 
          / 60.0 - Pause_Length_Minutes, 1) 
          AS [Duration Last Cycle (Minutes)], 
          CA.Pause_Length_Minutes, 
          ET_Minutes_Last24Hours AS [Duration Last 24 hours], 
          ET_Minutes_Last7Days AS [Duration Last 7 Days]
      FROM T_Current_Activity AS CA INNER JOIN
          T_MT_Database_State_Name ON 
          CA.State = T_MT_Database_State_Name.ID INNER JOIN
          T_Update_State_Name ON 
          CA.Update_State = T_Update_State_Name.ID
      WHERE (CA.Type = 'MSeq')) M
ORDER BY Began DESC

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

