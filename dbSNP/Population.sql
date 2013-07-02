/****** Object:  Table [dbo].[Population] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Population](
	[pop_id] [int] NOT NULL,
	[handle] [varchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[loc_pop_id] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[loc_pop_id_upp] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[create_time] [smalldatetime] NULL,
	[last_updated_time] [smalldatetime] NULL,
	[src_id] [int] NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_handle_loc_pop_id] ******/
CREATE NONCLUSTERED INDEX [i_handle_loc_pop_id] ON [dbo].[Population] 
(
	[handle] ASC,
	[loc_pop_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_handle_loc_pop_id_upp] ******/
CREATE NONCLUSTERED INDEX [i_handle_loc_pop_id_upp] ON [dbo].[Population] 
(
	[handle] ASC,
	[loc_pop_id_upp] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
