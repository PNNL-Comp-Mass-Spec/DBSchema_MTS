/****** Object:  View [dbo].[V_DMS_Analysis_Job_Requests_Jobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_DMS_Analysis_Job_Requests_Jobs]
AS
SELECT Job, [Pri.], State, [Tool Name], Dataset, [Parm File], 
    [Settings File], Organism, [Organism DB], ProteinCollectionList, 
    ProteinOptions, Comment, Created, Started, Finished, CPU, 
    Batch, [#ReqestID]
FROM GIGASAX.DMS5.dbo.V_Analysis_Request_Jobs_List_Report AS
     T1


GO
