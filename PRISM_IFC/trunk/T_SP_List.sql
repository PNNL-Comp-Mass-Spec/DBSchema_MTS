/****** Object:  Table [dbo].[T_SP_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_SP_List](
	[SP_ID] [int] IDENTITY(1,1) NOT NULL,
	[Category_ID] [int] NOT NULL CONSTRAINT [DF_T_SP_List_Category_ID]  DEFAULT (0),
	[SP_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[SP_Description] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_SP_List] PRIMARY KEY NONCLUSTERED 
(
	[SP_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_SP_List] ******/
CREATE UNIQUE CLUSTERED INDEX [IX_T_SP_List] ON [dbo].[T_SP_List] 
(
	[SP_Name] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_SP_List]  WITH CHECK ADD  CONSTRAINT [FK_T_SP_List_T_SP_Categories] FOREIGN KEY([Category_ID])
REFERENCES [T_SP_Categories] ([Category_ID])
GO
ALTER TABLE [dbo].[T_SP_List] CHECK CONSTRAINT [FK_T_SP_List_T_SP_Categories]
GO
