/****** Object:  View [dbo].[V_NET_Update_Task_Summary] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_NET_Update_Task_Summary
AS
SELECT UT.Task_ID, UT.Processing_State, 
    UTSN.Processing_State_Name, UT.Task_Created, UT.Task_Start, 
    UT.Task_Finish, UT.Task_AssignedProcessorName
FROM dbo.T_GANET_Update_Task UT INNER JOIN
    dbo.T_GANET_Update_Task_State_Name UTSN ON 
    UT.Processing_State = UTSN.Processing_State


GO
GRANT VIEW DEFINITION ON [dbo].[V_NET_Update_Task_Summary] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_NET_Update_Task_Summary] TO [MTS_DB_Lite] AS [dbo]
GO
