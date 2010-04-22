/****** Object:  View [dbo].[V_Peak_Matching_Param_Files] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Peak_Matching_Param_Files
AS
SELECT     Param_File_ID, Param_File_Name, Param_File_Description, 0 AS PM_Task_Usage_Count, Date_Created, Date_Modified
FROM         dbo.T_Peak_Matching_Param_Files
WHERE     (Active = 1)

GO
