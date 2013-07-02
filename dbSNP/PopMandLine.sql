/****** Object:  Table [dbo].[PopMandLine] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PopMandLine](
	[pop_id] [int] NOT NULL,
	[line_num] [tinyint] NOT NULL,
	[line] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[create_time] [smalldatetime] NULL,
	[last_updated_time] [smalldatetime] NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_pid_line_num] ******/
CREATE CLUSTERED INDEX [i_pid_line_num] ON [dbo].[PopMandLine] 
(
	[pop_id] ASC,
	[line_num] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
