SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_DMS_Analysis_Job_Import_Ex]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_DMS_Analysis_Job_Import_Ex]
GO


CREATE VIEW dbo.V_DMS_Analysis_Job_Import_Ex
AS
SELECT T1.*
FROM GIGASAX.DMS5.dbo.V_Analysis_Job_Export_Ex T1


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

