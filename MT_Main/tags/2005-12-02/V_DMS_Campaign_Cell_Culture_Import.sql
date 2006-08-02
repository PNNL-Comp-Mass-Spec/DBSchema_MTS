SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_DMS_Campaign_Cell_Culture_Import]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_DMS_Campaign_Cell_Culture_Import]
GO

CREATE VIEW dbo.V_DMS_Campaign_Cell_Culture_Import
AS
SELECT Campaign, CellCulture, CC_ID
FROM GIGASAX.DMS5.dbo.V_Export_Campaign_Cell_Culture t1

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

