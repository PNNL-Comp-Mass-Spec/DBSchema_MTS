/****** Object:  View [dbo].[V_DMS_Campaign] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_DMS_Campaign
AS
SELECT Campaign_Num AS Campaign, Campaign_ID AS ID, 
    CM_comment AS Comment, CM_created AS Created
FROM GIGASAX.DMS5.dbo.T_Campaign t1

GO
