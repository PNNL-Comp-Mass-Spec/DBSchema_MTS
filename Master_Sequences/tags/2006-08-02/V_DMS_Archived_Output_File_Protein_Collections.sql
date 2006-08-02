SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_DMS_Archived_Output_File_Protein_Collections]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_DMS_Archived_Output_File_Protein_Collections]
GO

CREATE VIEW dbo.V_DMS_Archived_Output_File_Protein_Collections
AS
SELECT Archived_File_ID, Archived_File_Path, File_Type_Name, 
    Archived_File_State, Protein_Collection_Count, 
    Protein_Collection_ID, FileName
FROM GIGASAX.Protein_Sequences.dbo.V_Archived_Output_File_Protein_Collections
     AS V1

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

