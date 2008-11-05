/****** Object:  View [dbo].[V_Mass_Tags_Near_Duplicates_PlusProteins] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_Mass_Tags_Near_Duplicates_PlusProteins]
AS
SELECT S.Mass_Tag_ID,
       S.CompareMTID,
       S.Monoisotopic_Mass,
       S.CompareMass,
       S.NET,
       S.CompareNET,
       S.Peptide,
       S.ComparePeptide,
       S.PMTQS,
       S.ComparePMTQS,
       S.MassDiffPPM,
       S.NETDiff,
       S.MassAvg,
       S.NETAvg,
       MIN(Prot1.Reference) AS ProteinFirst,
       MIN(Prot2.Reference) AS ProteinFirst_Compare,
       Count(DISTINCT Prot1.Reference) AS ProteinCount,
       Count(DISTINCT Prot2.Reference) AS ProteinCount_Compare
FROM V_Mass_Tags_Near_Duplicates S
     LEFT OUTER JOIN T_Mass_Tag_to_Protein_Map MTPM1
       ON S.Mass_Tag_ID = MTPM1.Mass_Tag_ID
     INNER JOIN T_Proteins Prot1
       ON MTPM1.Ref_ID = Prot1.Ref_ID
     LEFT OUTER JOIN T_Mass_Tag_to_Protein_Map MTPM2
       ON S.CompareMTID = MTPM2.Mass_Tag_ID
     INNER JOIN T_Proteins Prot2
       ON MTPM2.Ref_ID = Prot2.Ref_ID
WHERE (Abs(S.MassDiffPPM) < 6)
GROUP BY S.Mass_Tag_ID, S.CompareMTID, S.Monoisotopic_Mass, S.CompareMass, S.NET, S.CompareNET, 
         S.Peptide, S.ComparePeptide, S.PMTQS, S.ComparePMTQS, S.MassDiffPPM, S.NETDiff, S.MassAvg, S.NETAvg

GO
