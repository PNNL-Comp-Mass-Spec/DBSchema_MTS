/****** Object:  Table [dbo].[T_Folder_Paths] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Folder_Paths](
	[Function] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Client_Path] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Server_Path] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_Folder_Paths] PRIMARY KEY CLUSTERED 
(
	[Function] ASC
) ON [PRIMARY]
) ON [PRIMARY]

GO
