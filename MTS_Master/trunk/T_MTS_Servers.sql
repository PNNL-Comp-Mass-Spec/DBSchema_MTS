/****** Object:  Table [dbo].[T_MTS_Servers] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MTS_Servers](
	[Server_ID] [int] NOT NULL,
	[Server_Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Active] [tinyint] NOT NULL,
 CONSTRAINT [PK_T_MTS_Servers] PRIMARY KEY CLUSTERED 
(
	[Server_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_MTS_Servers] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_MTS_Servers] ON [dbo].[T_MTS_Servers] 
(
	[Server_Name] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
GO
