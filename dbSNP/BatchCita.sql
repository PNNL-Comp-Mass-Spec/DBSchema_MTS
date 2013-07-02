/****** Object:  Table [dbo].[BatchCita] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BatchCita](
	[batch_id] [int] NOT NULL,
	[position] [int] NOT NULL,
	[pub_id] [int] NOT NULL,
	[citation] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[create_time] [smalldatetime] NULL,
	[last_updated_time] [smalldatetime] NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_pub_id] ******/
CREATE NONCLUSTERED INDEX [i_pub_id] ON [dbo].[BatchCita] 
(
	[pub_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
