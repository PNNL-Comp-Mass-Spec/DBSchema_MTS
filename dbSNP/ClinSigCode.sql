/****** Object:  Table [dbo].[ClinSigCode] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ClinSigCode](
	[code] [int] NOT NULL,
	[abbrev] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[descrip] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[create_time] [smalldatetime] NULL,
	[last_updated_time] [smalldatetime] NULL,
	[severity_level] [tinyint] NOT NULL
) ON [PRIMARY]

GO
