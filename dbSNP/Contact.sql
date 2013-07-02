/****** Object:  Table [dbo].[Contact] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Contact](
	[batch_id] [int] NOT NULL,
	[handle] [varchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[fax] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[phone] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[email] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[lab] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[institution] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[address] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[create_time] [smalldatetime] NULL,
	[last_updated_time] [smalldatetime] NULL
) ON [PRIMARY]

GO
