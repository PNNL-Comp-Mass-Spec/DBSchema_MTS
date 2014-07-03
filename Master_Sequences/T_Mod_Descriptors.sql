/****** Object:  Table [dbo].[T_Mod_Descriptors] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Mod_Descriptors](
	[Seq_ID] [int] NOT NULL,
	[Mass_Correction_Tag] [char](8) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Position] [smallint] NOT NULL,
	[Mod_Descriptor_ID] [int] IDENTITY(1,1) NOT NULL,
 CONSTRAINT [PK_T_Mod_Descriptors] PRIMARY KEY NONCLUSTERED 
(
	[Mod_Descriptor_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
GRANT INSERT ON [dbo].[T_Mod_Descriptors] TO [DMS_SP_User] AS [dbo]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_Mod_Descriptors] ******/
CREATE CLUSTERED INDEX [IX_T_Mod_Descriptors] ON [dbo].[T_Mod_Descriptors]
(
	[Seq_ID] ASC,
	[Mass_Correction_Tag] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Mod_Descriptors]  WITH CHECK ADD  CONSTRAINT [FK_T_Mod_Descriptors_T_Sequence] FOREIGN KEY([Seq_ID])
REFERENCES [dbo].[T_Sequence] ([Seq_ID])
GO
ALTER TABLE [dbo].[T_Mod_Descriptors] CHECK CONSTRAINT [FK_T_Mod_Descriptors_T_Sequence]
GO
