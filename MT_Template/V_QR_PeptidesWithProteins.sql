/****** Object:  View [dbo].[V_QR_PeptidesWithProteins] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_QR_PeptidesWithProteins]
AS
----------------------------------------------------------------------------------------------
-- This query was adapted from the query used by stored procedure QRRetrievePeptidesMultiQID
-- Suggested sort: 
--   ORDER BY IsNull(Sample_Name, Convert(varchar(12), QID)), Reference, Mass_Tag_ID
----------------------------------------------------------------------------------------------
--
SELECT QD.Quantitation_ID AS QID,
	   QD.SampleName AS Sample_Name,
       QR.Ref_ID,
       Prot.Reference,
       -- Left(Prot.Description, 900) AS Protein_Description,
       QRD.Mass_Tag_ID,
       MT.Peptide,
       ROUND(QRD.MT_Abundance, 4) AS MT_Abundance,
       CASE
           WHEN QD.Normalize_To_Standard_Abundances > 0 THEN Round(QRD.MT_Abundance / 100.0 *
                                                                   QD.Standard_Abundance_Max 
                                                                   + QD.Standard_Abundance_Min, 0)
           ELSE Round(QRD.MT_Abundance, 4)
       END AS MT_Abundance_Unscaled,
       ROUND(QRD.MT_Match_Score_Avg, 3) AS MT_STAC_Score,
       ROUND(QRD.MT_Uniqueness_Probability_Avg, 3) AS MT_Uniqueness_Probability,
       ROUND(QRD.MT_FDR_Threshold_Avg, 4) AS MT_FDR_Threshold,
       ROUND(MT.Monoisotopic_Mass, 5) AS Monoisotopic_Mass,
       MT.Min_MSGF_SpecProb AS Min_MSGF_SpecProb,
	   MT.Min_PSM_FDR,
       MT.Mod_Description,
       ISNULL(CSN.Cleavage_State_Name, 'Unknown') AS Cleavage_State_Name,
       QRD.ORF_Count AS Protein_Count
FROM T_Quantitation_Description QD
     INNER JOIN T_Quantitation_Results QR
       ON QD.Quantitation_ID = QR.Quantitation_ID
     INNER JOIN T_Quantitation_ResultDetails QRD
       ON QR.QR_ID = QRD.QR_ID
     INNER JOIN T_Mass_Tags MT
       ON QRD.Mass_Tag_ID = MT.Mass_Tag_ID
     LEFT OUTER JOIN T_Mass_Tag_to_Protein_Map MTPM
       ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID AND
          QR.Ref_ID = MTPM.Ref_ID
     LEFT OUTER JOIN T_Peptide_Cleavage_State_Name CSN
       ON MTPM.Cleavage_State = CSN.Cleavage_State
     LEFT OUTER JOIN T_Proteins Prot
       ON QR.Ref_ID = Prot.Ref_ID


GO
GRANT VIEW DEFINITION ON [dbo].[V_QR_PeptidesWithProteins] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_QR_PeptidesWithProteins] TO [MTS_DB_Lite] AS [dbo]
GO
