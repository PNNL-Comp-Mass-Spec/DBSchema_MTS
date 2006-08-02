SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_DMS_Organism_DB_File_Import]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_DMS_Organism_DB_File_Import]
GO

CREATE VIEW dbo.V_DMS_Organism_DB_File_Import
AS
SELECT t1.*
FROM GIGASAX.DMS5.dbo.V_Organism_DB_File_Export t1

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

