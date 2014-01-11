/****** Object:  Table [dbo].[T_MyEMSL_Cache_Paths] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MyEMSL_Cache_Paths](
	[Cache_PathID] [int] IDENTITY(1,1) NOT NULL,
	[Dataset_ID] [int] NOT NULL,
	[Parent_Path] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Dataset_Folder] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Results_Folder_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_MyEMSL_Cache_Paths] PRIMARY KEY CLUSTERED 
(
	[Cache_PathID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_MyEMSL_Cache_Paths] ******/
CREATE NONCLUSTERED INDEX [IX_T_MyEMSL_Cache_Paths] ON [dbo].[T_MyEMSL_Cache_Paths] 
(
	[Dataset_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
