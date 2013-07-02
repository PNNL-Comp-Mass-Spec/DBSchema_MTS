/****** Object:  Table [dbo].[SNPPubmed] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SNPPubmed](
	[snp_id] [int] NULL,
	[subsnp_id] [int] NULL,
	[pubmed_id] [int] NULL,
	[type] [varchar](16) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[score] [int] NOT NULL,
	[upd_time] [datetime] NOT NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_rs_ss_pmid] ******/
CREATE CLUSTERED INDEX [i_rs_ss_pmid] ON [dbo].[SNPPubmed] 
(
	[snp_id] ASC,
	[subsnp_id] ASC,
	[pubmed_id] ASC,
	[type] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
