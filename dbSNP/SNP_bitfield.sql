/****** Object:  Table [dbo].[SNP_bitfield] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SNP_bitfield](
	[snp_id] [int] NOT NULL,
	[ver_code] [tinyint] NULL,
	[link_prop_b1] [tinyint] NULL,
	[link_prop_b2] [tinyint] NULL,
	[gene_prop_b1] [tinyint] NULL,
	[gene_prop_b2] [tinyint] NULL,
	[map_prop] [tinyint] NULL,
	[freq_prop] [tinyint] NULL,
	[gty_prop] [tinyint] NULL,
	[hapmap_prop] [tinyint] NULL,
	[pheno_prop] [tinyint] NULL,
	[variation_class] [tinyint] NOT NULL,
	[quality_check] [tinyint] NULL,
	[upd_time] [datetime] NOT NULL,
	[encoding] [binary](1) NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_link_prop_b2] ******/
CREATE NONCLUSTERED INDEX [i_link_prop_b2] ON [dbo].[SNP_bitfield] 
(
	[link_prop_b2] ASC,
	[snp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
