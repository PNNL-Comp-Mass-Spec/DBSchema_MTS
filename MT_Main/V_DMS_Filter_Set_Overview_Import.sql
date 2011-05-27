/****** Object:  View [dbo].[V_DMS_Filter_Set_Overview_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create VIEW V_DMS_Filter_Set_Overview_Import
AS
SELECT t1.Filter_Type_ID,
       t1.Filter_Type_Name,
       t1.Filter_Set_ID,
       t1.Filter_Set_Name,
       t1.Filter_Set_Description
FROM Gigasax.DMS5.dbo.V_Filter_Set_Overview t1

GO
