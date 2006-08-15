/****** Object:  View [dbo].[V_IFC_Mass_Tag_to_Protein_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_IFC_Mass_Tag_to_Protein_Map
AS
SELECT     Mass_Tag_ID, Mass_Tag_Name, Ref_ID, Cleavage_State, Fragment_Number, Fragment_Span, Residue_Start, Residue_End, Repeat_Count, 
                      Terminus_State
FROM         dbo.T_Mass_Tag_to_Protein_Map


GO
