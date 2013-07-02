/****** Object:  Table [dbo].[RsMergeArch] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RsMergeArch](
	[rsHigh] [int] NULL,
	[rsLow] [int] NULL,
	[build_id] [int] NULL,
	[orien] [tinyint] NULL,
	[create_time] [datetime] NOT NULL,
	[last_updated_time] [datetime] NOT NULL,
	[rsCurrent] [int] NULL,
	[orien2Current] [tinyint] NULL,
	[comment] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]

GO
