/****** Object:  Table [dbo].[b137_SNPContigProtein] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[b137_SNPContigProtein](
	[snp_id] [int] NOT NULL,
	[contig_gi] [int] NOT NULL,
	[contig_start] [int] NOT NULL,
	[contig_stop] [int] NOT NULL,
	[contig_orien] [tinyint] NOT NULL,
	[contig_allele] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[mrna_gi] [int] NOT NULL,
	[mrna_acc] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[mrna_ver] [smallint] NOT NULL,
	[mrna_start] [int] NULL,
	[mrna_stop] [int] NULL,
	[mrna_orien] [tinyint] NULL,
	[gene_symbol] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[gene_id] [int] NULL,
	[prot_gi] [int] NULL,
	[prot_acc] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[prot_ver] [smallint] NULL,
	[prot_start] [int] NULL,
	[prot_stop] [int] NULL,
	[frame] [tinyint] NULL,
	[var_allele] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[residue] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[mrna_codon] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[codon] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[fxn_class] [int] NOT NULL,
	[in_stop_codon] [tinyint] NULL
) ON [PRIMARY]

GO
