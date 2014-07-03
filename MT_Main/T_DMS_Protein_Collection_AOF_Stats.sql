/****** Object:  Table [dbo].[T_DMS_Protein_Collection_AOF_Stats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_DMS_Protein_Collection_AOF_Stats](
	[Archived_File_ID] [int] NOT NULL,
	[Filesize] [bigint] NOT NULL,
	[Protein_Collection_Count] [int] NULL,
	[Protein_Count] [int] NULL,
	[Residue_Count] [int] NULL,
	[Archived_File_Name] [varchar](500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Last_Affected] [datetime] NOT NULL,
 CONSTRAINT [PK_T_DMS_Protein_Collection_AOF_Stats] PRIMARY KEY CLUSTERED 
(
	[Archived_File_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_DMS_Protein_Collection_AOF_Stats_Name] ******/
CREATE NONCLUSTERED INDEX [IX_T_DMS_Protein_Collection_AOF_Stats_Name] ON [dbo].[T_DMS_Protein_Collection_AOF_Stats]
(
	[Archived_File_Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_DMS_Protein_Collection_AOF_Stats] ADD  CONSTRAINT [DF_T_DMS_Protein_Collection_AOF_Stats_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
