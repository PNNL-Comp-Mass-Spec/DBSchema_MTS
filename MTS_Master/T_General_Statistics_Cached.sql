/****** Object:  Table [dbo].[T_General_Statistics_Cached] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_General_Statistics_Cached](
	[Server_Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[DBName] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Category] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Label] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Value] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Entry_ID] [int] NOT NULL,
	[Entered] [datetime] NOT NULL,
 CONSTRAINT [PK_T_General_Statistics_MT_DBs] PRIMARY KEY CLUSTERED 
(
	[Server_Name] ASC,
	[DBName] ASC,
	[Entry_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_General_Statistics_Cached] ADD  CONSTRAINT [DF_T_General_Statistics_Cached_Entered]  DEFAULT (getdate()) FOR [Entered]
GO
