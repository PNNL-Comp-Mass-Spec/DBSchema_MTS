SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_SIC_Job_to_PeptideHit_Map]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_SIC_Job_to_PeptideHit_Map]
GO


CREATE VIEW dbo.V_SIC_Job_to_PeptideHit_Map
AS
SELECT AD_PeptideHit.Job, AD_SIC.Job AS SIC_Job, 
    dbo.T_Datasets.Dataset_ID
FROM dbo.T_Analysis_Description AD_SIC INNER JOIN
    dbo.T_Datasets ON 
    AD_SIC.Job = dbo.T_Datasets.SIC_Job INNER JOIN
    dbo.T_Analysis_Description AD_PeptideHit ON 
    dbo.T_Datasets.Dataset_ID = AD_PeptideHit.Dataset_ID
WHERE (AD_PeptideHit.ResultType = 'Peptide_Hit')


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

