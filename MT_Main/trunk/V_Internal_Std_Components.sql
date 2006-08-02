SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Internal_Std_Components]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Internal_Std_Components]
GO

CREATE VIEW dbo.V_Internal_Standards_Composition
AS
SELECT dbo.T_Internal_Standards.Internal_Std_Mix_ID, 
    dbo.T_Internal_Standards.Name AS Internal_Std_Name, 
    dbo.T_Internal_Standards.Description AS Internal_Std_Description,
     dbo.T_Internal_Standards.Type AS Internal_Std_Type, 
    dbo.T_Internal_Std_Components.Seq_ID, 
    dbo.T_Internal_Std_Composition.Concentration, 
    dbo.T_Internal_Std_Components.Description AS Component_Description,
     dbo.T_Internal_Std_Components.Peptide, 
    dbo.T_Internal_Std_Components.Monoisotopic_Mass, 
    dbo.T_Internal_Std_Components.Charge_Minimum, 
    dbo.T_Internal_Std_Components.Charge_Maximum, 
    dbo.T_Internal_Std_Components.Charge_Highest_Abu, 
    dbo.T_Internal_Std_Components.Min_NET, 
    dbo.T_Internal_Std_Components.Max_NET, 
    dbo.T_Internal_Std_Components.Avg_NET, 
    dbo.T_Internal_Std_Components.Cnt_NET, 
    dbo.T_Internal_Std_Components.StD_NET, 
    dbo.T_Internal_Std_Components.PNET
FROM dbo.T_Internal_Standards INNER JOIN
    dbo.T_Internal_Std_Composition ON 
    dbo.T_Internal_Standards.Internal_Std_Mix_ID = dbo.T_Internal_Std_Composition.Internal_Std_Mix_ID
     INNER JOIN
    dbo.T_Internal_Std_Components ON 
    dbo.T_Internal_Std_Composition.Seq_ID = dbo.T_Internal_Std_Components.Seq_ID

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

