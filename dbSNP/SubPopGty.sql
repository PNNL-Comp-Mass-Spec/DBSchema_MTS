/****** Object:  Table [dbo].[SubPopGty] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SubPopGty](
	[subpop_id] [int] NOT NULL,
	[gty_id] [int] NOT NULL,
	[gty_str] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[cnt] [real] NULL,
	[freq] [real] NULL,
	[last_updated_time] [smalldatetime] NOT NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_gty_id] ******/
CREATE NONCLUSTERED INDEX [i_gty_id] ON [dbo].[SubPopGty] 
(
	[gty_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_subpop_id] ******/
CREATE NONCLUSTERED INDEX [i_subpop_id] ON [dbo].[SubPopGty] 
(
	[subpop_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
