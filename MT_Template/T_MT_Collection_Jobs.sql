/****** Object:  Table [dbo].[T_MT_Collection_Jobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MT_Collection_Jobs](
	[MT_Collection_ID] [int] NOT NULL,
	[Job] [int] NOT NULL,
 CONSTRAINT [PK_T_MT_Collection_Jobs] PRIMARY KEY CLUSTERED 
(
	[MT_Collection_ID] ASC,
	[Job] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_MT_Collection_Jobs]  WITH CHECK ADD  CONSTRAINT [FK_T_MT_Collection_Jobs_T_MT_Collection] FOREIGN KEY([MT_Collection_ID])
REFERENCES [dbo].[T_MT_Collection] ([MT_Collection_ID])
GO
ALTER TABLE [dbo].[T_MT_Collection_Jobs] CHECK CONSTRAINT [FK_T_MT_Collection_Jobs_T_MT_Collection]
GO
