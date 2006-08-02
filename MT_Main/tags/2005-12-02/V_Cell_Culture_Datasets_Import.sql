SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Cell_Culture_Datasets_Import]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Cell_Culture_Datasets_Import]
GO


create view V_Cell_Culture_Datasets_Import
AS
SELECT     CellCulture, CellCultureID, DatasetID
FROM
OPENROWSET('SQLOLEDB', 'gigasax'; 'DMSWebUser'; 'icr4fun', 'SELECT * FROM dms5.dbo.V_Export_Cell_Culture_Datasets')

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

