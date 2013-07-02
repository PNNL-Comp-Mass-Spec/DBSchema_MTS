/****** Object:  Table [dbo].[dn_snpFxnCnt] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dn_snpFxnCnt](
	[build_id] [int] NOT NULL,
	[fxn_class] [tinyint] NULL,
	[snp_cnt] [int] NOT NULL,
	[gene_cnt] [int] NOT NULL,
	[create_time] [smalldatetime] NOT NULL,
	[last_updated_time] [smalldatetime] NOT NULL,
	[tax_id] [int] NOT NULL
) ON [PRIMARY]

GO
