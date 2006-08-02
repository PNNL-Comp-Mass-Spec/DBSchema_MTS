SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Analysis_Job_Unmapped_Peptide_DB]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Analysis_Job_Unmapped_Peptide_DB]
GO

CREATE VIEW dbo.V_Analysis_Job_Unmapped_Peptide_DB
AS
SELECT TOP 100 PERCENT DAJI.OrganismDBName, 
    COUNT(DAJI.Job) AS Matching_Job_Count, MAX(DAJI.Job) 
    AS Max_Job_Number
FROM dbo.T_Analysis_Job_to_Peptide_DB_Map AJPDM RIGHT OUTER
     JOIN
    dbo.V_DMS_Analysis_Job_Import DAJI ON 
    AJPDM.Job = DAJI.Job
WHERE (AJPDM.Job IS NULL) AND 
    (DAJI.ResultType = 'Peptide_Hit')
GROUP BY DAJI.OrganismDBName
ORDER BY MAX(DAJI.Job) DESC, COUNT(DAJI.Job) DESC

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

