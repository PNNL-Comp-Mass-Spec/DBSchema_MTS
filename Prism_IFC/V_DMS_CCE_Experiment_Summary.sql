/****** Object:  View [dbo].[V_DMS_CCE_Experiment_Summary] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_DMS_CCE_Experiment_Summary]
AS
SELECT Experiment, [Exp Reason], [Exp Comment], Campaign, 
    Organism, [Cell Cultures]
FROM GIGASAX.DMS5.dbo.V_CCE_Experiment_Summary AS t1


GO
