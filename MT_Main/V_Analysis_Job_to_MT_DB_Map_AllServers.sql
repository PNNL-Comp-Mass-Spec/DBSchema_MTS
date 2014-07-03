/****** Object:  View [dbo].[V_Analysis_Job_to_MT_DB_Map_AllServers] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_Analysis_Job_to_MT_DB_Map_AllServers]
AS
SELECT Server_Name, Job, ResultType, DB_Name, Last_Affected, 
    Process_State
FROM POGO.MTS_Master.dbo.V_Analysis_Job_to_MT_DB_Map AS V_Analysis_Job_to_MT_DB_Map_1


GO
