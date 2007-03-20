/****** Object:  View [dbo].[V_DMS_Analysis_Job_Requests] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_DMS_Analysis_Job_Requests]
AS
SELECT Request, Name, State, Requestor, Created, Tool, 
    [Param File], Organism, [Organism DB File], 
    ProteinCollectionList, ProteinOptions, Datasets, Comment, 
    Jobs
FROM GIGASAX.DMS5.dbo.V_Analysis_Job_Request_List_Report AS T1


GO
