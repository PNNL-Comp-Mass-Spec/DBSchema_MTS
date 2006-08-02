SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_IFC_Mass_Tag_to_Protein_Map]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_IFC_Mass_Tag_to_Protein_Map]
GO


CREATE VIEW dbo.V_IFC_Mass_Tag_to_Protein_Map
AS
SELECT     Mass_Tag_ID, Mass_Tag_Name, Ref_ID, Cleavage_State, Fragment_Number, Fragment_Span, Residue_Start, Residue_End, Repeat_Count, 
                      Terminus_State
FROM         dbo.T_Mass_Tag_to_Protein_Map


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

