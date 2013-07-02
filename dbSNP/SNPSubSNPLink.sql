/****** Object:  Table [dbo].[SNPSubSNPLink] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SNPSubSNPLink](
	[subsnp_id] [int] NULL,
	[snp_id] [int] NULL,
	[substrand_reversed_flag] [tinyint] NULL,
	[create_time] [datetime] NULL,
	[last_updated_time] [datetime] NULL,
	[build_id] [int] NULL,
	[comment] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_ss] ******/
CREATE CLUSTERED INDEX [i_ss] ON [dbo].[SNPSubSNPLink] 
(
	[subsnp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_rs] ******/
CREATE NONCLUSTERED INDEX [i_rs] ON [dbo].[SNPSubSNPLink] 
(
	[snp_id] ASC,
	[subsnp_id] ASC,
	[substrand_reversed_flag] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
