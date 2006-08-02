SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_DMS_Protein_Collection_List_Import]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_DMS_Protein_Collection_List_Import]
GO


CREATE VIEW dbo.V_DMS_Protein_Collection_List_Import
AS
SELECT *
FROM GIGASAX.Protein_Sequences.dbo.V_Protein_Collection_List_Export
     V_Protein_Collection_List_Export_1


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

