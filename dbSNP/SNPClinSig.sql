/****** Object:  Table [dbo].[SNPClinSig] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SNPClinSig](
	[hgvs_g] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[snp_id] [int] NULL,
	[tested] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[clin_sig_id] [int] NOT NULL,
	[upd_time] [datetime] NOT NULL,
	[clin_sig_id_by_rs] [int] NOT NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_rs_hgvs] ******/
CREATE CLUSTERED INDEX [i_rs_hgvs] ON [dbo].[SNPClinSig] 
(
	[hgvs_g] ASC,
	[snp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
