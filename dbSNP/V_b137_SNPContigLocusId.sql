/****** Object:  View [dbo].[V_b137_SNPContigLocusId] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW V_b137_SNPContigLocusId AS (
SELECT snp_id,
       contig_acc,
       contig_ver,
       asn_from,
       asn_to,
       locus_id,
       locus_symbol,
       mrna_acc,
       mrna_ver,
       protein_acc,
       protein_ver,
       fxn_class,
       reading_frame,
       allele,
       residue,
       aa_position,
       build_id,
       ctg_id,
       mrna_start,
       mrna_stop,
       codon,
       protRes,
       contig_gi,
       mrna_gi,
       mrna_orien,
       cp_mrna_ver,
       cp_mrna_gi,
       verComp,
       fc.abbrev AS Fxn_Code_Abbrev,
       fc.descrip AS Fxn_Code_Description,
       fc.top_level_class AS Fxn_Code_Top_Level,
       fc.is_coding AS Fxn_Code_Is_Coding,
       fc.is_exon AS Fxn_Code_Is_Exon,
       fc.var_prop_effect_code AS Fxn_Code_var_prop_effect_code,
       fc.var_prop_gene_loc_code AS Fxn_Code_var_prop_gene_loc_code,
       fc.SO_ID AS Fxn_Code_SO_ID
FROM dbSNP.dbo.b137_SNPContigLocusId AS SNP
     INNER JOIN SnpFunctionCode FC
       ON Snp.fxn_class = FC.Code
)

GO
GRANT VIEW DEFINITION ON [dbo].[V_b137_SNPContigLocusId] TO [pnl\rodr657] AS [dbo]
GO
