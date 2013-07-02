/****** Object:  Table [dbo].[SubSNP_top_or_bot] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SubSNP_top_or_bot](
	[subsnp_id] [int] NOT NULL,
	[top_or_bot] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[step] [tinyint] NULL,
	[last_updated_time] [smalldatetime] NULL
) ON [PRIMARY]

GO
