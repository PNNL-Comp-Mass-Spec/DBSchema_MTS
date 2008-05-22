/****** Object:  View [dbo].[V_DMS_Archived_Output_File_Protein_Collections] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_DMS_Archived_Output_File_Protein_Collections]
AS
SELECT Archived_File_ID, Archived_File_Path, File_Type_Name, 
    Archived_File_State, Protein_Collection_Count, 
    Protein_Collection_ID, FileName
FROM Protein_Sequences.dbo.V_Archived_Output_File_Protein_Collections
     AS V1

GO
