SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_IFC_Proteins]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_IFC_Proteins]
GO


CREATE VIEW dbo.V_IFC_Proteins
AS
SELECT Ref_ID, Reference, Description, Protein_Sequence, 
    Protein_Residue_Count, Monoisotopic_Mass, Protein_DB_ID, 
    External_Reference_ID, External_Protein_ID
FROM dbo.T_Proteins


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

