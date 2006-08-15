/****** Object:  Table [dbo].[T_Seq_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Seq_Map](
	[Seq_ID] [int] NOT NULL,
	[Map_ID] [int] NOT NULL,
 CONSTRAINT [PK_T_Seq_Map] PRIMARY KEY NONCLUSTERED 
(
	[Seq_ID] ASC,
	[Map_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Seq_Map_Map_ID] ******/
CREATE NONCLUSTERED INDEX [IX_T_Seq_Map_Map_ID] ON [dbo].[T_Seq_Map] 
(
	[Map_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
GO
GRANT INSERT ON [dbo].[T_Seq_Map] TO [DMS_SP_User]
GO
ALTER TABLE [dbo].[T_Seq_Map]  WITH CHECK ADD  CONSTRAINT [FK_T_Seq_Map_T_Sequence] FOREIGN KEY([Seq_ID])
REFERENCES [T_Sequence] ([Seq_ID])
GO
ALTER TABLE [dbo].[T_Seq_Map] CHECK CONSTRAINT [FK_T_Seq_Map_T_Sequence]
GO
