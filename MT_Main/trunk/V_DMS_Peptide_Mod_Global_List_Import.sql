/****** Object:  View [dbo].[V_DMS_Peptide_Mod_Global_List_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_DMS_Peptide_Mod_Global_List_Import
AS
SELECT t1.*
FROM OPENROWSET('SQLOLEDB', 'gigasax'; 'DMSWebUser'; 
    'icr4fun', 
    'SELECT * FROM DMS5.dbo.V_Peptide_Mod_Global_List_Export')
     t1

GO
