/****** Object:  View [dbo].[V_PM_Results_FDR_Stats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW V_PM_Results_FDR_Stats
AS
SELECT PM.Task_ID,
       MMD.MD_ID,
       IsNull(MMD.AMT_Count_1pct_FDR, 0) AS AMT_Count_1pct_FDR,
       IsNull(MMD.AMT_Count_5pct_FDR, 0) AS AMT_Count_5pct_FDR,
       IsNull(MMD.AMT_Count_10pct_FDR, 0) AS AMT_Count_10pct_FDR,
       IsNull(MMD.AMT_Count_25pct_FDR, 0) AS AMT_Count_25pct_FDR,
       IsNull(MMD.AMT_Count_50pct_FDR, 0) AS AMT_Count_50pct_FDR
FROM T_Peak_Matching_Task PM
     LEFT OUTER JOIN T_Match_Making_Description MMD
       ON PM.MD_ID = MMD.MD_ID

GO
