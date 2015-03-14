/****** Object:  View [dbo].[V_Import_Analysis_Result_Type_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_Import_Analysis_Result_Type_List
AS
SELECT Value
FROM dbo.T_Process_Config
WHERE (Name = 'Import_Result_Type')


GO
GRANT VIEW DEFINITION ON [dbo].[V_Import_Analysis_Result_Type_List] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_Import_Analysis_Result_Type_List] TO [MTS_DB_Lite] AS [dbo]
GO
