/****** Object:  View [dbo].[V_DMS_Filter_Sets_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE view V_DMS_Filter_Sets_Import
AS
SELECT TOP 100 PERCENT t1.*
FROM GIGASAX.DMS5.dbo.V_Filter_Sets t1

GO
