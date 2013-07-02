/****** Object:  Table [dbo].[b137_SNPContigLocusId] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[b137_SNPContigLocusId](
	[snp_id] [int] NULL,
	[contig_acc] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[contig_ver] [tinyint] NULL,
	[asn_from] [int] NULL,
	[asn_to] [int] NULL,
	[locus_id] [int] NULL,
	[locus_symbol] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[mrna_acc] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[mrna_ver] [smallint] NOT NULL,
	[protein_acc] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[protein_ver] [smallint] NULL,
	[fxn_class] [int] NULL,
	[reading_frame] [int] NULL,
	[allele] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[residue] [varchar](1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[aa_position] [int] NULL,
	[build_id] [varchar](4) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[ctg_id] [int] NULL,
	[mrna_start] [int] NULL,
	[mrna_stop] [int] NULL,
	[codon] [varchar](1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[protRes] [char](3) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[contig_gi] [int] NULL,
	[mrna_gi] [int] NULL,
	[mrna_orien] [tinyint] NULL,
	[cp_mrna_ver] [int] NULL,
	[cp_mrna_gi] [int] NULL,
	[verComp] [int] NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_rsCtgMrna] ******/
CREATE CLUSTERED INDEX [i_rsCtgMrna] ON [dbo].[b137_SNPContigLocusId] 
(
	[snp_id] ASC,
	[contig_acc] ASC,
	[asn_from] ASC,
	[locus_id] ASC,
	[allele] ASC,
	[mrna_start] ASC,
	[mrna_gi] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_rs] ******/
CREATE NONCLUSTERED INDEX [i_rs] ON [dbo].[b137_SNPContigLocusId] 
(
	[snp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [IX_b137_SNPContigLocusId_protein_acc] ******/
CREATE NONCLUSTERED INDEX [IX_b137_SNPContigLocusId_protein_acc] ON [dbo].[b137_SNPContigLocusId] 
(
	[protein_acc] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
