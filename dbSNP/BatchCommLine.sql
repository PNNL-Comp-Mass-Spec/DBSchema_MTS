/****** Object:  Table [dbo].[BatchCommLine] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BatchCommLine](
	[batch_id] [int] NOT NULL,
	[line_num] [tinyint] NOT NULL,
	[line] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[create_time] [smalldatetime] NULL,
	[last_updated_time] [smalldatetime] NULL
) ON [PRIMARY]

GO
