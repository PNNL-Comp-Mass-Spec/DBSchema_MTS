/****** Object:  Table [dbo].[GtyFreqBySsPop] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[GtyFreqBySsPop](
	[subsnp_id] [int] NOT NULL,
	[pop_id] [int] NOT NULL,
	[unigty_id] [int] NOT NULL,
	[source] [varchar](1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[cnt] [real] NULL,
	[freq] [real] NULL,
	[last_updated_time] [datetime] NOT NULL
) ON [PRIMARY]

GO
