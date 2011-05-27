/****** Object:  View [dbo].[V_MT_DBs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_MT_DBs]
AS
SELECT Server_Name,
       MT_DB_ID,
       MT_DB_Name,
       State_ID,
       State,
       Last_Affected,
       Last_Online,
       [Description],
       Organism,
       Campaign,
       DB_Schema_Version
FROM V_MTS_MT_DBs
WHERE Server_Active = 1 AND State_ID < 15
UNION
SELECT Server_Name,
       MT_DB_ID,
       MT_DB_Name,
       State_ID,
       State,
       Last_Affected,
       Last_Online,
       [Description],
       Organism,
       Campaign,
       DB_Schema_Version
FROM V_MTS_MT_DBs
WHERE (Server_Active = 1 AND State_ID >= 15 OR
       Server_Active = 0) AND
      NOT MT_DB_Name IN ( SELECT MT_DB_Name
                          FROM V_MTS_MT_DBs
                          WHERE Server_Active = 1 AND State_ID < 15 )


GO
