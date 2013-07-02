/****** Object:  Table [dbo].[GeneIdToName] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[GeneIdToName](
	[gene_id] [int] NOT NULL,
	[gene_symbol] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[gene_name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[gene_type] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[tax_id] [int] NOT NULL,
	[last_update_time] [smalldatetime] NOT NULL,
	[ref_tax_id] [int] NOT NULL,
	[dbSNP_tax_id] [int] NOT NULL,
	[ins_time] [smalldatetime] NULL
) ON [PRIMARY]

GO
