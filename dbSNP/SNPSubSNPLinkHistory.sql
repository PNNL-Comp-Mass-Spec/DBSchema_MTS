/****** Object:  Table [dbo].[SNPSubSNPLinkHistory] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SNPSubSNPLinkHistory](
	[subsnp_id] [int] NULL,
	[snp_id] [int] NULL,
	[build_id] [int] NULL,
	[history_create_time] [datetime] NOT NULL,
	[link_create_time] [datetime] NULL,
	[link_last_updated_time] [datetime] NULL,
	[orien] [tinyint] NULL,
	[build_id_when_history_made] [int] NULL,
	[comment] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_snp_id] ******/
CREATE CLUSTERED INDEX [i_snp_id] ON [dbo].[SNPSubSNPLinkHistory] 
(
	[snp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_build_id] ******/
CREATE NONCLUSTERED INDEX [i_build_id] ON [dbo].[SNPSubSNPLinkHistory] 
(
	[build_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_build_id_when_history_made] ******/
CREATE NONCLUSTERED INDEX [i_build_id_when_history_made] ON [dbo].[SNPSubSNPLinkHistory] 
(
	[build_id_when_history_made] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_ss_rs] ******/
CREATE NONCLUSTERED INDEX [i_ss_rs] ON [dbo].[SNPSubSNPLinkHistory] 
(
	[subsnp_id] ASC,
	[snp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
