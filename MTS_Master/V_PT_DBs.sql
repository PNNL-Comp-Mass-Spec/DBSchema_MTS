/****** Object:  View [dbo].[V_PT_DBs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_PT_DBs]
AS
SELECT Server_Name,
       Peptide_DB_ID,
       Peptide_DB_Name,
       State_ID,
       State,
       Last_Affected,
       Last_Online,
       Description,
       Organism,
       DB_Schema_Version
FROM V_MTS_Peptide_DBs
WHERE Server_Active = 1 AND State_ID < 15
UNION
SELECT Server_Name,
       Peptide_DB_ID,
       Peptide_DB_Name,
       State_ID,
       State,
       Last_Affected,
       Last_Online,
       Description,
       Organism,
       DB_Schema_Version
FROM V_MTS_Peptide_DBs
WHERE (Server_Active = 1 AND State_ID >= 15 OR
       Server_Active = 0) AND
      NOT Peptide_DB_Name IN ( SELECT Peptide_DB_Name
                               FROM V_MTS_Peptide_DBs
                               WHERE Server_Active = 1 AND State_ID < 15 )



GO
