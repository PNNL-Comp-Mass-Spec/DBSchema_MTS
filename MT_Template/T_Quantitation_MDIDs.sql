/****** Object:  Table [dbo].[T_Quantitation_MDIDs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Quantitation_MDIDs](
	[Q_MDID_ID] [int] IDENTITY(1,1) NOT NULL,
	[Quantitation_ID] [int] NOT NULL,
	[MD_ID] [int] NOT NULL,
	[Replicate] [smallint] NOT NULL,
	[Fraction] [smallint] NOT NULL,
	[TopLevelFraction] [smallint] NOT NULL,
 CONSTRAINT [PK_T_Quantitation_MDIDs] PRIMARY KEY NONCLUSTERED 
(
	[Q_MDID_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Quantitation_MDIDs] ******/
CREATE CLUSTERED INDEX [IX_T_Quantitation_MDIDs] ON [dbo].[T_Quantitation_MDIDs] 
(
	[Quantitation_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
GRANT DELETE ON [dbo].[T_Quantitation_MDIDs] TO [DMS_SP_User] AS [dbo]
GO
GRANT INSERT ON [dbo].[T_Quantitation_MDIDs] TO [DMS_SP_User] AS [dbo]
GO
GRANT SELECT ON [dbo].[T_Quantitation_MDIDs] TO [DMS_SP_User] AS [dbo]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_MDIDs] TO [DMS_SP_User] AS [dbo]
GO
ALTER TABLE [dbo].[T_Quantitation_MDIDs]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Quantitation_MDIDs_T_Match_Making_Description] FOREIGN KEY([MD_ID])
REFERENCES [T_Match_Making_Description] ([MD_ID])
GO
ALTER TABLE [dbo].[T_Quantitation_MDIDs] CHECK CONSTRAINT [FK_T_Quantitation_MDIDs_T_Match_Making_Description]
GO
ALTER TABLE [dbo].[T_Quantitation_MDIDs]  WITH CHECK ADD  CONSTRAINT [FK_T_Quantitation_MDIDs_T_Quantitation_Description] FOREIGN KEY([Quantitation_ID])
REFERENCES [T_Quantitation_Description] ([Quantitation_ID])
GO
ALTER TABLE [dbo].[T_Quantitation_MDIDs] CHECK CONSTRAINT [FK_T_Quantitation_MDIDs_T_Quantitation_Description]
GO
ALTER TABLE [dbo].[T_Quantitation_MDIDs] ADD  CONSTRAINT [DF_T_Quantitation_MDIDs_Replicate]  DEFAULT (1) FOR [Replicate]
GO
ALTER TABLE [dbo].[T_Quantitation_MDIDs] ADD  CONSTRAINT [DF_T_Quantitation_MDIDs_Fraction]  DEFAULT (1) FOR [Fraction]
GO
ALTER TABLE [dbo].[T_Quantitation_MDIDs] ADD  CONSTRAINT [DF_T_Quantitation_MDIDs_TopLevelFraction]  DEFAULT (1) FOR [TopLevelFraction]
GO
