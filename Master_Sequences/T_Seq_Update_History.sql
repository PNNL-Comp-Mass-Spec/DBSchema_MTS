/****** Object:  Table [dbo].[T_Seq_Update_History] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Seq_Update_History](
	[Seq_ID] [int] NOT NULL,
	[Clean_Sequence] [varchar](850) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Mod_Count] [smallint] NOT NULL,
	[Mod_Description_Old] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Mod_Description_New] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Seq_ID_Pointer] [int] NULL,
	[Last_Affected] [datetime] NOT NULL,
	[Monoisotopic_Mass] [float] NULL,
	[GANET_Predicted] [real] NULL,
 CONSTRAINT [PK_T_Seq_Update_History] PRIMARY KEY CLUSTERED 
(
	[Seq_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Seq_Update_History_Last_Affected] ******/
CREATE NONCLUSTERED INDEX [IX_T_Seq_Update_History_Last_Affected] ON [dbo].[T_Seq_Update_History] 
(
	[Last_Affected] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Seq_Update_History_Mod_Count] ******/
CREATE NONCLUSTERED INDEX [IX_T_Seq_Update_History_Mod_Count] ON [dbo].[T_Seq_Update_History] 
(
	[Mod_Count] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Seq_Update_History_Seq_ID_Pointer] ******/
CREATE NONCLUSTERED INDEX [IX_T_Seq_Update_History_Seq_ID_Pointer] ON [dbo].[T_Seq_Update_History] 
(
	[Seq_ID_Pointer] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Seq_Update_History] ADD  CONSTRAINT [DF_T_Seq_Update_History_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
