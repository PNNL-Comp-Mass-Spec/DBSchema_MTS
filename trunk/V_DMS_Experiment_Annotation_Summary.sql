/****** Object:  View [dbo].[V_DMS_Experiment_Annotation_Summary] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_DMS_Experiment_Annotation_Summary]
AS
SELECT P.Experiment, P.Exp_ID, E.Comment, 
    E.[Reason For Experiment], [Acceptability], [CollaboratorPI], 
    [ExpQuality], [Project], [Purpose], 
    [ReasonForFailedAcceptability]
FROM Gigasax.DMS5.dbo.V_Experiment_Annotations EA PIVOT (Min([Value])
     FOR Key_Name IN ([Acceptability], [CollaboratorPI], 
    [ExpQuality], [Project], [Purpose], 
    [ReasonForFailedAcceptability])) P INNER JOIN
    V_DMS_Experiment_List_Import_Ex E ON 
    P.Experiment = E.Experiment

GO
