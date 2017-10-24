/****** Object:  View [dbo].[V_DMS_Param_Files] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Param_Files]
AS
SELECT Param_File_ID,
       Param_File_Name,
       Param_File_Type,
       Param_File_Description,
       Date_Created,
       Date_Modified,
       Job_Usage_Count,
       Job_Usage_Last_Year,
       Valid
FROM S_V_Param_File_List_Report


GO
