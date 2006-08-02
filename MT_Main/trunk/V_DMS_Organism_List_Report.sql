SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_DMS_Organism_List_Report]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_DMS_Organism_List_Report]
GO

CREATE VIEW dbo.V_DMS_Organism_List_Report
AS
SELECT t1.*
FROM GIGASAX.DMS5.dbo.V_Organism_List_Report t1

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

