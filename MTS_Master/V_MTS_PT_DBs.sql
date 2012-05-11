/****** Object:  View [dbo].[V_MTS_PT_DBs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE VIEW [dbo].[V_MTS_PT_DBs]
AS
SELECT Peptide_DB_ID,
       Peptide_DB_Name,
       Server_Name,
       State_ID,
       State,
       Last_Affected,
       Last_Online,
       [Description],
       Organism,
       DB_Schema_Version,
       Comment,
       Created,
       Server_Active
FROM dbo.V_MTS_Peptide_DBs


GO
