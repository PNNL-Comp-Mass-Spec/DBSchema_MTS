/****** Object:  Table [dbo].[Batch] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Batch](
	[batch_id] [int] NOT NULL,
	[handle] [varchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[loc_batch_id] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[loc_batch_id_upp] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[batch_type] [char](3) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[status] [tinyint] NULL,
	[simul_sts_status] [tinyint] NOT NULL,
	[moltype] [varchar](8) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[method_id] [int] NOT NULL,
	[samplesize] [int] NULL,
	[synonym_type] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[submitted_time] [smalldatetime] NOT NULL,
	[linkout_url] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[pop_id] [int] NULL,
	[last_updated_time] [smalldatetime] NULL,
	[success_rate_int] [int] NULL,
	[build_id] [int] NULL,
	[tax_id] [int] NOT NULL,
	[ss_cnt] [int] NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_handle_loc_batch_id] ******/
CREATE NONCLUSTERED INDEX [i_handle_loc_batch_id] ON [dbo].[Batch] 
(
	[handle] ASC,
	[loc_batch_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_last_updated] ******/
CREATE NONCLUSTERED INDEX [i_last_updated] ON [dbo].[Batch] 
(
	[last_updated_time] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_lbid_u] ******/
CREATE NONCLUSTERED INDEX [i_lbid_u] ON [dbo].[Batch] 
(
	[loc_batch_id_upp] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_method_id] ******/
CREATE NONCLUSTERED INDEX [i_method_id] ON [dbo].[Batch] 
(
	[method_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_pop_id] ******/
CREATE NONCLUSTERED INDEX [i_pop_id] ON [dbo].[Batch] 
(
	[pop_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_submitted_time] ******/
CREATE NONCLUSTERED INDEX [i_submitted_time] ON [dbo].[Batch] 
(
	[submitted_time] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_success_rate_int] ******/
CREATE NONCLUSTERED INDEX [i_success_rate_int] ON [dbo].[Batch] 
(
	[success_rate_int] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_tax_id] ******/
CREATE NONCLUSTERED INDEX [i_tax_id] ON [dbo].[Batch] 
(
	[tax_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
