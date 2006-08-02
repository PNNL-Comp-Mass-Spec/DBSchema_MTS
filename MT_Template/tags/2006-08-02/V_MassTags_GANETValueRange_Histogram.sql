SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_MassTags_GANETValueRange_Histogram]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_MassTags_GANETValueRange_Histogram]
GO


CREATE VIEW dbo.V_MassTags_GANETValueRange_Histogram
AS
SELECT GANET_Bin, COUNT(*) AS Match_Count
FROM (SELECT GANET_Bin = CASE WHEN Avg_GANET IS NULL 
          THEN 0 WHEN Avg_GANET BETWEEN 0.0 AND 
          0.1 THEN 1 WHEN Avg_GANET BETWEEN 0.1 AND 
          0.2 THEN 2 WHEN Avg_GANET BETWEEN 0.2 AND 
          0.3 THEN 3 WHEN Avg_GANET BETWEEN 0.3 AND 
          0.4 THEN 4 WHEN Avg_GANET BETWEEN 0.4 AND 
          0.5 THEN 5 WHEN Avg_GANET BETWEEN 0.5 AND 
          0.6 THEN 6 WHEN Avg_GANET BETWEEN 0.6 AND 
          0.7 THEN 7 WHEN Avg_GANET BETWEEN 0.7 AND 
          0.8 THEN 8 WHEN Avg_GANET BETWEEN 0.8 AND 
          0.9 THEN 9 WHEN Avg_GANET BETWEEN 0.9 AND 
          1.0 THEN 10 ELSE 0 END
      FROM T_Mass_Tags_NET) StatsQ
GROUP BY GANET_Bin


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

