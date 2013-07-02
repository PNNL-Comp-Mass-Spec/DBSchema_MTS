/****** Object:  Table [dbo].[SuspectReasonCode] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SuspectReasonCode](
	[code] [int] NOT NULL,
	[abbrev] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[descrip] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[create_time] [smalldatetime] NULL,
	[last_update_time] [smalldatetime] NULL
) ON [PRIMARY]

GO
