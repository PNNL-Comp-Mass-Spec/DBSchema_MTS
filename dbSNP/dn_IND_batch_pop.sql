/****** Object:  Table [dbo].[dn_IND_batch_pop] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dn_IND_batch_pop](
	[batch_id] [smallint] NOT NULL,
	[pop_id] [int] NOT NULL,
	[update_time] [datetime] NOT NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_pid] ******/
CREATE CLUSTERED INDEX [i_pid] ON [dbo].[dn_IND_batch_pop] 
(
	[pop_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
