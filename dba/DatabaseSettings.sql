/****** Object:  Table [dbo].[DatabaseSettings] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DatabaseSettings](
	[DBName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[SchemaTracking] [bit] NULL,
	[LogFileAlerts] [bit] NULL,
	[LongQueryAlerts] [bit] NULL,
	[Reindex] [bit] NULL,
 CONSTRAINT [pk_DatabaseSettings] PRIMARY KEY CLUSTERED 
(
	[DBName] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
