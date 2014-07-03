/****** Object:  Table [dbo].[T_Process_Config] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Process_Config](
	[Process_Config_ID] [int] IDENTITY(100,1) NOT NULL,
	[Name] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Value] [varchar](250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_Process_Config] PRIMARY KEY NONCLUSTERED 
(
	[Process_Config_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_Process_Config] ******/
CREATE CLUSTERED INDEX [IX_T_Process_Config] ON [dbo].[T_Process_Config]
(
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Process_Config]  WITH CHECK ADD  CONSTRAINT [FK_T_Process_Config_T_Process_Config_Parameters] FOREIGN KEY([Name])
REFERENCES [dbo].[T_Process_Config_Parameters] ([Name])
GO
ALTER TABLE [dbo].[T_Process_Config] CHECK CONSTRAINT [FK_T_Process_Config_T_Process_Config_Parameters]
GO
