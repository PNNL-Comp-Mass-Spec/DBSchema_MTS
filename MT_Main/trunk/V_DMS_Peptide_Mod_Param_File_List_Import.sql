/****** Object:  View [dbo].[V_DMS_Peptide_Mod_Param_File_List_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE VIEW V_DMS_Peptide_Mod_Param_File_List_Import
AS
SELECT t1.*
FROM GIGASAX.DMS5.dbo.V_Peptide_Mod_Param_File_List_Export t1

GO
