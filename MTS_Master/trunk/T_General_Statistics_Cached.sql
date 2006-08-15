/****** Object:  Table [dbo].[T_General_Statistics_Cached]    Script Date: 08/14/2006 20:22:55 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_General_Statistics_Cached](
	[Server_Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[DBName] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Category] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Label] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Value] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Entry_ID] [int] NOT NULL,
 CONSTRAINT [PK_T_General_Statistics_MT_DBs] PRIMARY KEY CLUSTERED 
(
	[Server_Name] ASC,
	[DBName] ASC,
	[Entry_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
