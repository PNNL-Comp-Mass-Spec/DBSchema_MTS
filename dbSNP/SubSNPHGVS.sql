/****** Object:  Table [dbo].[SubSNPHGVS] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SubSNPHGVS](
	[subsnp_id] [int] NOT NULL,
	[sub_hgvs_c] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[sub_hgvs_g] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[sub_hgvs_p] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[cal_hgvs_c] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[cal_hgvs_g] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[cal_hgvs_p] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[upd_time] [smalldatetime] NULL,
	[gene_id] [int] NULL
) ON [PRIMARY]

GO
