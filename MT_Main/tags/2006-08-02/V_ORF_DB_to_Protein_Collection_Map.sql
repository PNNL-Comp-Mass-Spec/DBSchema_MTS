SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_ORF_DB_to_Protein_Collection_Map]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_ORF_DB_to_Protein_Collection_Map]
GO

CREATE VIEW dbo.V_ORF_DB_to_Protein_Collection_Map
AS
SELECT TOP 100 PERCENT dbo.T_ORF_Database_List.ODB_ID, 
    dbo.T_ORF_Database_List.ODB_Name, 
    dbo.T_ORF_Database_List.ODB_Description, 
    dbo.T_ORF_Database_List.ODB_Organism, 
    REPLACE(dbo.T_ORF_Database_List.ODB_Fasta_File_Name, 
    '.fasta', '') AS Fasta_File_Name, 
    dbo.V_DMS_Protein_Collections_List_Report.[Collection ID], 
    dbo.V_DMS_Protein_Collections_List_Report.Name, 
    dbo.V_DMS_Protein_Collections_List_Report.State, 
    dbo.V_DMS_Protein_Collections_List_Report.[Protein Count]
FROM dbo.V_DMS_Protein_Collections_List_Report RIGHT OUTER JOIN
    dbo.T_ORF_Database_List ON 
    dbo.V_DMS_Protein_Collections_List_Report.Name = REPLACE(dbo.T_ORF_Database_List.ODB_Fasta_File_Name,
     '.fasta', '')
ORDER BY dbo.T_ORF_Database_List.ODB_Fasta_File_Name

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

