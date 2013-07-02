/****** Object:  Table [dbo].[SubSNP] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SubSNP](
	[subsnp_id] [int] NOT NULL,
	[known_snp_handle] [varchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[known_snp_loc_id] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[known_snp_loc_id_upp] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[batch_id] [int] NOT NULL,
	[loc_snp_id] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[loc_snp_id_upp] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[synonym_names] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[loc_sts_id] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[loc_sts_id_upp] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[segregate] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[indiv_homozygosity_detected] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PCR_confirmed_ind] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[gene_name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[sequence_len] [int] NULL,
	[samplesize] [int] NULL,
	[EXPRESSED_SEQUENCE_ind] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[SOMATIC_ind] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[sub_locus_id] [int] NULL,
	[create_time] [smalldatetime] NULL,
	[last_updated_time] [smalldatetime] NULL,
	[ancestral_allele] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[CpG_code] [tinyint] NULL,
	[variation_id] [int] NULL,
	[top_or_bot_strand] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[validation_status] [tinyint] NULL,
	[snp_id] [int] NULL,
	[tax_id] [int] NOT NULL,
	[chr_id] [tinyint] NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_bid_ss] ******/
CREATE NONCLUSTERED INDEX [i_bid_ss] ON [dbo].[SubSNP] 
(
	[batch_id] ASC,
	[subsnp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_loc_snp] ******/
CREATE NONCLUSTERED INDEX [i_loc_snp] ON [dbo].[SubSNP] 
(
	[loc_snp_id_upp] ASC,
	[subsnp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_ss_bid_loc] ******/
CREATE NONCLUSTERED INDEX [i_ss_bid_loc] ON [dbo].[SubSNP] 
(
	[subsnp_id] ASC,
	[batch_id] ASC,
	[loc_snp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_var] ******/
CREATE NONCLUSTERED INDEX [i_var] ON [dbo].[SubSNP] 
(
	[variation_id] ASC,
	[subsnp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
