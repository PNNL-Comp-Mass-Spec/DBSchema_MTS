/****** Object:  Table [dbo].[T_Quantitation_MDIDs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Quantitation_MDIDs](
	[Q_MDID_ID] [int] IDENTITY(1,1) NOT NULL,
	[Quantitation_ID] [int] NOT NULL,
	[MD_ID] [int] NOT NULL,
	[Replicate] [smallint] NOT NULL CONSTRAINT [DF_T_Quantitation_MDIDs_Replicate]  DEFAULT (1),
	[Fraction] [smallint] NOT NULL CONSTRAINT [DF_T_Quantitation_MDIDs_Fraction]  DEFAULT (1),
	[TopLevelFraction] [smallint] NOT NULL CONSTRAINT [DF_T_Quantitation_MDIDs_TopLevelFraction]  DEFAULT (1),
 CONSTRAINT [PK_T_Quantitation_MDIDs] PRIMARY KEY NONCLUSTERED 
(
	[Q_MDID_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Quantitation_MDIDs] ******/
CREATE CLUSTERED INDEX [IX_T_Quantitation_MDIDs] ON [dbo].[T_Quantitation_MDIDs] 
(
	[Quantitation_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
GO
GRANT SELECT ON [dbo].[T_Quantitation_MDIDs] TO [DMS_SP_User]
GO
GRANT INSERT ON [dbo].[T_Quantitation_MDIDs] TO [DMS_SP_User]
GO
GRANT DELETE ON [dbo].[T_Quantitation_MDIDs] TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_MDIDs] TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_MDIDs] ([Q_MDID_ID]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_MDIDs] ([Q_MDID_ID]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_MDIDs] ([Quantitation_ID]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_MDIDs] ([Quantitation_ID]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_MDIDs] ([MD_ID]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_MDIDs] ([MD_ID]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_MDIDs] ([Replicate]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_MDIDs] ([Replicate]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_MDIDs] ([Fraction]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_MDIDs] ([Fraction]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_MDIDs] ([TopLevelFraction]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_MDIDs] ([TopLevelFraction]) TO [DMS_SP_User]
GO
ALTER TABLE [dbo].[T_Quantitation_MDIDs]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Quantitation_MDIDs_T_Match_Making_Description] FOREIGN KEY([MD_ID])
REFERENCES [T_Match_Making_Description] ([MD_ID])
GO
ALTER TABLE [dbo].[T_Quantitation_MDIDs] CHECK CONSTRAINT [FK_T_Quantitation_MDIDs_T_Match_Making_Description]
GO
ALTER TABLE [dbo].[T_Quantitation_MDIDs]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Quantitation_MDIDs_T_Quantitation_Description] FOREIGN KEY([Quantitation_ID])
REFERENCES [T_Quantitation_Description] ([Quantitation_ID])
GO
ALTER TABLE [dbo].[T_Quantitation_MDIDs] CHECK CONSTRAINT [FK_T_Quantitation_MDIDs_T_Quantitation_Description]
GO
