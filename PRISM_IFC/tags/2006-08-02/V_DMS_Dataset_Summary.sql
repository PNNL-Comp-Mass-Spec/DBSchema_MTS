SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_DMS_Dataset_Summary]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_DMS_Dataset_Summary]
GO

CREATE VIEW dbo.V_DMS_Dataset_Summary
AS
SELECT t1.*
FROM GIGASAX.DMS5.dbo.V_Dataset_Detail_Report_Ex t1

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

