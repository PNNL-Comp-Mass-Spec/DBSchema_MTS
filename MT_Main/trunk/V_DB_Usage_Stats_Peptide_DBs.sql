SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_DB_Usage_Stats_Peptide_DBs]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_DB_Usage_Stats_Peptide_DBs]
GO

CREATE VIEW dbo.V_DB_Usage_Stats_Peptide_DBs
AS
SELECT TOP 100 PERCENT LookupQ.PDB_Name, 
    LookupQ.PDB_Description AS Description, 
    LookupQ.PDB_State AS State, LookupQ.Created_Max, 
    LookupQ.Last_Affected_Max, LookupQ.Job_Count, 
    DATEDIFF(month, LookupQ.Created_Max, GETDATE()) 
    AS Months_Since_Last_Job_Created, DATEDIFF(month, 
    LookupQ.Last_Affected_Max, GETDATE()) 
    AS Months_Since_Last_Job_Affected, 
    CA.[Duration Last Cycle (Minutes)], CA.[Duration Last 24 hours], 
    CA.[Duration Last 7 Days]
FROM (SELECT PDL.PDB_Name, PDL.PDB_Description, 
          PDL.PDB_State, MAX(AJPM.Created) AS Created_Max, 
          MAX(AJPM.Last_Affected) AS Last_Affected_Max, 
          COUNT(*) AS Job_Count
      FROM T_Analysis_Job_to_Peptide_DB_Map AJPM INNER JOIN
          T_Peptide_Database_List PDL ON 
          AJPM.PDB_ID = PDL.PDB_ID
      WHERE (PDL.PDB_State < 15)
      GROUP BY PDL.PDB_Name, PDL.PDB_Description, 
          PDL.PDB_State) LookupQ LEFT OUTER JOIN
    dbo.V_Current_Activity CA ON 
    LookupQ.PDB_Name = CA.Name
ORDER BY DATEDIFF(month, LookupQ.Last_Affected_Max, 
    GETDATE()) DESC, DATEDIFF(month, LookupQ.Created_Max, 
    GETDATE()) DESC

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

