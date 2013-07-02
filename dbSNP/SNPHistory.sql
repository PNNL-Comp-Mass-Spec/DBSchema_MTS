/****** Object:  Table [dbo].[SNPHistory] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SNPHistory](
	[snp_id] [int] NOT NULL,
	[create_time] [smalldatetime] NULL,
	[last_updated_time] [smalldatetime] NOT NULL,
	[history_create_time] [smalldatetime] NULL,
	[comment] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[reactivated_time] [smalldatetime] NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_hist_time] ******/
CREATE NONCLUSTERED INDEX [i_hist_time] ON [dbo].[SNPHistory] 
(
	[history_create_time] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
