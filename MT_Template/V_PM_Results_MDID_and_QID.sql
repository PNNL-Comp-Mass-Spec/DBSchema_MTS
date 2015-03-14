/****** Object:  View [dbo].[V_PM_Results_MDID_and_QID] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_PM_Results_MDID_and_QID]
AS
SELECT PM.Task_ID,
       PM.Job,
       MMD.MD_ID,
       V_MD_ID_to_QID_Map.Quantitation_ID,
       MMD.Ini_File_Name,
       MMD.MD_Comparison_Mass_Tag_Count AS Comparison_Mass_Tag_Count,
       MMD.MD_State
FROM T_Match_Making_Description MMD
     LEFT OUTER JOIN V_MD_ID_to_QID_Map
       ON MMD.MD_ID = V_MD_ID_to_QID_Map.MD_ID AND
          V_MD_ID_to_QID_Map.MemberCountRank = 1
     RIGHT OUTER JOIN T_Peak_Matching_Task PM
       ON MMD.MD_ID = PM.MD_ID       


GO
GRANT VIEW DEFINITION ON [dbo].[V_PM_Results_MDID_and_QID] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_PM_Results_MDID_and_QID] TO [MTS_DB_Lite] AS [dbo]
GO
