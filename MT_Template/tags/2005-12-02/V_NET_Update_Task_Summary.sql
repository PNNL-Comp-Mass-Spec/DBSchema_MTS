SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_NET_Update_Task_Summary]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_NET_Update_Task_Summary]
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

