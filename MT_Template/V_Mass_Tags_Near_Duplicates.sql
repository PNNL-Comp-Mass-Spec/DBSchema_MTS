/****** Object:  View [dbo].[V_Mass_Tags_Near_Duplicates] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create VIEW dbo.V_Mass_Tags_Near_Duplicates
AS
SELECT Mass_Tag_ID, Monoisotopic_Mass, Avg_GANET, Peptide, 
    CompareMTID, CompareMass, CompareNET, ComparePeptide, 
    MassDiffPPM, MassAvg, NETAvg
FROM (SELECT T .Mass_Tag_ID, 
          U.Mass_Tag_ID AS CompareMTID, T .Peptide, 
          U.Peptide AS ComparePeptide, T .Monoisotopic_Mass, 
          U.Monoisotopic_Mass AS CompareMass, 
          M.Avg_GANET, N .Avg_GANET AS CompareNET, 
          ABS(T .Monoisotopic_Mass - U.Monoisotopic_Mass) 
          / (t .monoisotopic_mass / 1e6) AS MassDiffPPM, 
          (T .Monoisotopic_Mass + U.Monoisotopic_Mass) 
          / 2 AS MassAvg, (M.Avg_GANET + N .Avg_GANET) 
          / 2 AS NETAvg
      FROM T_Mass_Tags T INNER JOIN
          T_Mass_Tags U ON 
          T .Mass_Tag_ID <> U.Mass_Tag_ID INNER JOIN
          T_Mass_Tags_NET M ON 
          T .Mass_Tag_ID = M.Mass_Tag_ID INNER JOIN
          T_Mass_Tags_NET N ON U.Mass_Tag_ID = N 
          .Mass_Tag_ID
      WHERE (ABS(M.Avg_GANET - N .Avg_GANET) < 0.05)) 
    LookupQ
WHERE (MassDiffPPM < 6)

GO
