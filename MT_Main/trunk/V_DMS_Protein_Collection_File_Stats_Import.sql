/****** Object:  View [dbo].[V_DMS_Protein_Collection_File_Stats_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_DMS_Protein_Collection_File_Stats_Import
AS
SELECT T1.*
FROM GIGASAX.Protein_Sequences.dbo.V_Archived_Output_File_Stats_Export
     T1

GO
