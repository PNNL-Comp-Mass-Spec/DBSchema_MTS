SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Import_Analysis_Result_Type_List]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Import_Analysis_Result_Type_List]
GO


CREATE VIEW dbo.V_Import_Analysis_Result_Type_List
AS
SELECT Value
FROM dbo.T_Process_Config
WHERE (Name = 'Import_Result_Type')


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

