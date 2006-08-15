/****** Object:  View [dbo].[V_DMS_Analysis_Job_Import_Ex] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_DMS_Analysis_Job_Import_Ex
AS
SELECT T1.*
FROM GIGASAX.DMS5.dbo.V_Analysis_Job_Export_Ex T1


GO
