/****** Object:  Table [dbo].[SNP] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SNP](
	[snp_id] [int] NULL,
	[avg_heterozygosity] [real] NULL,
	[het_se] [real] NULL,
	[create_time] [datetime] NULL,
	[last_updated_time] [datetime] NULL,
	[CpG_code] [tinyint] NULL,
	[tax_id] [int] NULL,
	[validation_status] [tinyint] NULL,
	[exemplar_subsnp_id] [int] NOT NULL,
	[univar_id] [int] NULL,
	[cnt_subsnp] [int] NULL,
	[map_property] [tinyint] NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_rs] ******/
CREATE CLUSTERED INDEX [i_rs] ON [dbo].[SNP] 
(
	[snp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_exemplarSs] ******/
CREATE NONCLUSTERED INDEX [i_exemplarSs] ON [dbo].[SNP] 
(
	[exemplar_subsnp_id] ASC,
	[snp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
