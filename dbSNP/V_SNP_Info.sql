/****** Object:  View [dbo].[V_SNP_Info] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_SNP_Info] AS (
SELECT SNP.snp_id,
       SNP.avg_heterozygosity,
       SNP.het_se,
       SNP.CpG_code,
       SNP.tax_id,
       SNP.validation_status,
       SNP.exemplar_subsnp_id,
       SNP.univar_id,
       SNP.cnt_subsnp,
       SNP.map_property,
       AF.allele_id,
       AF.freq,
       AF.[count],
       AF.is_minor_allele,
       Allele.allele,
       Allele.rev_allele_id,
       Allele.src
FROM SNP
     INNER JOIN SNPAlleleFreq_TGP AF
       ON SNP.snp_id = AF.snp_id
     INNER JOIN Allele
       ON AF.allele_id = Allele.allele_id

)



GO
GRANT VIEW DEFINITION ON [dbo].[V_SNP_Info] TO [pnl\rodr657] AS [dbo]
GO
