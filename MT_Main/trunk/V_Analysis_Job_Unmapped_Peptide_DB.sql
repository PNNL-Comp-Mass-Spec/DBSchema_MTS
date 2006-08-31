/****** Object:  View [dbo].[V_Analysis_Job_Unmapped_Peptide_DB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_Analysis_Job_Unmapped_Peptide_DB
AS
SELECT TOP 100 PERCENT DAJI.OrganismDBName, 
    DAJI.ProteinCollectionList, DAJI.ProteinOptions, 
    COUNT(DAJI.Job) AS Matching_Job_Count, MAX(DAJI.Job) 
    AS Max_Job_Number
FROM dbo.T_Analysis_Job_to_Peptide_DB_Map AJPDM RIGHT OUTER
     JOIN
    dbo.V_DMS_Analysis_Job_Import DAJI ON 
    AJPDM.Job = DAJI.Job
WHERE (AJPDM.Job IS NULL) AND 
    (DAJI.ResultType = 'Peptide_Hit')
GROUP BY DAJI.OrganismDBName, DAJI.ProteinCollectionList, 
    DAJI.ProteinOptions
ORDER BY MAX(DAJI.Job) DESC, COUNT(DAJI.Job) DESC


GO
