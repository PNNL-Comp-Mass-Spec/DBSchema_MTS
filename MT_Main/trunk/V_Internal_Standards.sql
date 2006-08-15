/****** Object:  View [dbo].[V_Internal_Standards] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Internal_Standards
AS
SELECT Internal_Std_Mix_ID, Name, Description, Type
FROM dbo.T_Internal_Standards

GO
