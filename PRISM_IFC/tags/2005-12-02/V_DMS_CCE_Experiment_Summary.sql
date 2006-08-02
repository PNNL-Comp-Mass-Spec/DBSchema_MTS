SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_DMS_CCE_Experiment_Summary]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_DMS_CCE_Experiment_Summary]
GO

CREATE VIEW dbo.V_DMS_CCE_Experiment_Summary
AS
SELECT Experiment, [Exp Reason], [Exp Comment], Campaign, 
    Organism, [Cell Cultures]
FROM GIGASAX.DMS5.dbo.V_CCE_Experiment_Summary t1

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

