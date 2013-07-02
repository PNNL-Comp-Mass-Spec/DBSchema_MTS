/****** Object:  Table [dbo].[dn_table_rowcount] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dn_table_rowcount](
	[tabname] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[row_cnt] [int] NOT NULL,
	[build_id] [int] NOT NULL,
	[update_time] [datetime] NOT NULL,
	[rows_in_spaceused] [int] NULL,
	[reserved_KB_spaceused] [int] NULL,
	[data_KB_spaceused] [int] NULL,
	[index_size_KB_spaceused] [int] NULL,
	[unused_KB_spaceused] [int] NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_b_size] ******/
CREATE CLUSTERED INDEX [i_b_size] ON [dbo].[dn_table_rowcount] 
(
	[build_id] DESC,
	[reserved_KB_spaceused] DESC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
