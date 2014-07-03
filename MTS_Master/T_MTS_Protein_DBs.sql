/****** Object:  Table [dbo].[T_MTS_Protein_DBs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MTS_Protein_DBs](
	[Protein_DB_ID] [int] NOT NULL,
	[Protein_DB_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Server_ID] [int] NOT NULL,
	[State_ID] [int] NOT NULL,
	[Last_Affected] [datetime] NOT NULL,
	[DB_Schema_Version] [real] NOT NULL,
	[Comment] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Last_Online] [date] NULL,
 CONSTRAINT [PK_T_MTS_Protein_DBs] PRIMARY KEY CLUSTERED 
(
	[Protein_DB_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_MTS_Protein_DBs] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_MTS_Protein_DBs] ON [dbo].[T_MTS_Protein_DBs]
(
	[Protein_DB_Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_MTS_Protein_DBs] ADD  CONSTRAINT [DF_T_MTS_Protein_DBs_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
ALTER TABLE [dbo].[T_MTS_Protein_DBs] ADD  CONSTRAINT [DF_T_MTS_Protein_DBs_DB_Schema_Version]  DEFAULT ((1)) FOR [DB_Schema_Version]
GO
ALTER TABLE [dbo].[T_MTS_Protein_DBs] ADD  CONSTRAINT [DF_T_MTS_Protein_DBs_Comment]  DEFAULT ('') FOR [Comment]
GO
ALTER TABLE [dbo].[T_MTS_Protein_DBs]  WITH CHECK ADD  CONSTRAINT [FK_T_MTS_Protein_DBs_T_MTS_Servers] FOREIGN KEY([Server_ID])
REFERENCES [dbo].[T_MTS_Servers] ([Server_ID])
GO
ALTER TABLE [dbo].[T_MTS_Protein_DBs] CHECK CONSTRAINT [FK_T_MTS_Protein_DBs_T_MTS_Servers]
GO
