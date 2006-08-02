SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Orphaned_MTS_DBs]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Orphaned_MTS_DBs]
GO

create VIEW dbo.V_Orphaned_MTS_DBs
AS
SELECT TOP 100 PERCENT DBType, Name, State
FROM (SELECT 'MT' AS DBType, M.MTL_Name AS Name, 
          M.MTL_State AS State
      FROM T_MT_Database_List M LEFT OUTER JOIN
          master.dbo.sysdatabases SD ON 
          M.MTL_Name = SD.name
      WHERE (M.MTL_State <> 100) AND (SD.name IS NULL)
      UNION
      SELECT 'PT' AS DBType, P.PDB_Name AS Name, 
          P.PDB_State AS State
      FROM T_Peptide_Database_List P LEFT OUTER JOIN
          master.dbo.sysdatabases SD ON 
          P.PDB_Name = SD.name
      WHERE (P.PDB_State <> 100) AND (SD.name IS NULL)
      UNION
      SELECT 'ORF' AS DBType, O.ODB_Name AS Name, 
          O.ODB_State AS State
      FROM T_ORF_Database_List O LEFT OUTER JOIN
          master.dbo.sysdatabases SD ON 
          O.ODB_Name = SD.name
      WHERE (O.ODB_State <> 100) AND (SD.name IS NULL)) 
    AS LookupQ
ORDER BY dbtype, name

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

