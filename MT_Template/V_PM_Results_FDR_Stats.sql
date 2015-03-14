/****** Object:  View [dbo].[V_PM_Results_FDR_Stats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_PM_Results_FDR_Stats]
AS
SELECT PM.Task_ID,
       MMD.MD_ID,
       IsNull(MMD.AMT_Count_1pct_FDR, 0) AS AMT_Count_1pct_FDR,
       IsNull(MMD.AMT_Count_5pct_FDR, 0) AS AMT_Count_5pct_FDR,
       IsNull(MMD.AMT_Count_10pct_FDR, 0) AS AMT_Count_10pct_FDR,
       IsNull(MMD.AMT_Count_25pct_FDR, 0) AS AMT_Count_25pct_FDR,
       IsNull(MMD.AMT_Count_50pct_FDR, 0) AS AMT_Count_50pct_FDR,
       MMD.Refine_Mass_Cal_PPMShift
FROM T_Peak_Matching_Task PM
     LEFT OUTER JOIN T_Match_Making_Description MMD
       ON PM.MD_ID = MMD.MD_ID


GO
GRANT VIEW DEFINITION ON [dbo].[V_PM_Results_FDR_Stats] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_PM_Results_FDR_Stats] TO [MTS_DB_Lite] AS [dbo]
GO
