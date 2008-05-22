/****** Object:  Table [dbo].[T_Mass_Tag_Mod_Info] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Mass_Tag_Mod_Info](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[Mass_Tag_ID] [int] NOT NULL,
	[Mod_Name] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Mod_Position] [smallint] NOT NULL,
	[Entered] [smalldatetime] NOT NULL CONSTRAINT [DF_T_Mass_Tag_Mod_Info_Entered]  DEFAULT (getdate()),
 CONSTRAINT [PK_T_Mass_Tag_Mod_Info] PRIMARY KEY NONCLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Mass_Tag_Mod_Info_Mass_Tag_ID_Mod_Position] ******/
CREATE CLUSTERED INDEX [IX_T_Mass_Tag_Mod_Info_Mass_Tag_ID_Mod_Position] ON [dbo].[T_Mass_Tag_Mod_Info] 
(
	[Mass_Tag_ID] ASC,
	[Mod_Position] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Mass_Tag_Mod_Info]  WITH CHECK ADD  CONSTRAINT [FK_T_Mass_Tag_Mod_Info_T_Mass_Tags] FOREIGN KEY([Mass_Tag_ID])
REFERENCES [T_Mass_Tags] ([Mass_Tag_ID])
GO
ALTER TABLE [dbo].[T_Mass_Tag_Mod_Info] CHECK CONSTRAINT [FK_T_Mass_Tag_Mod_Info_T_Mass_Tags]
GO
