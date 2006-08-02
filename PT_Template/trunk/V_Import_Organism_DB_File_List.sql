SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Import_Organism_DB_File_List]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Import_Organism_DB_File_List]
GO


CREATE VIEW dbo.V_Import_Organism_DB_File_List
AS
SELECT Value
FROM dbo.T_Process_Config
WHERE (Name = 'Organism_DB_File_Name')


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

