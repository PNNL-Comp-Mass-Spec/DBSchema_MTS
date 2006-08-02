SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_GANET_Peptides]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_GANET_Peptides]
GO


CREATE VIEW dbo.V_GANET_Peptides
AS
SELECT TOP 100 PERCENT Pep.Analysis_ID, Pep.Scan_Number, 
    Seq.Clean_Sequence, 
    CASE WHEN Len(IsNull(Seq.Mod_Description, '')) 
    = 0 THEN 'none' ELSE Seq.Mod_Description END AS Mod_Description,
     Pep.Seq_ID, Pep.Charge_State, CONVERT(real, Pep.MH) 
    AS MH, SS.XCorr, SS.DeltaCn, CONVERT(real, SS.Sp) AS Sp, 
    Seq.Cleavage_State_Max, Pep.Scan_Time_Peak_Apex
FROM dbo.T_Sequence Seq INNER JOIN
    dbo.T_Peptides Pep INNER JOIN
    dbo.T_Score_Sequest SS ON 
    Pep.Peptide_ID = SS.Peptide_ID ON 
    Seq.Seq_ID = Pep.Seq_ID
ORDER BY Pep.Analysis_ID, Pep.Scan_Number, Pep.Charge_State, 
    SS.XCorr DESC, Pep.Seq_ID


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

