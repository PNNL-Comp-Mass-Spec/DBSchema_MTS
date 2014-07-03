/****** Object:  Table [dbo].[T_DMS_Organism_DB_Info] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_DMS_Organism_DB_Info](
	[ID] [int] NOT NULL,
	[FileName] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Organism] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Description] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Active] [tinyint] NOT NULL,
	[NumProteins] [int] NULL,
	[NumResidues] [bigint] NULL,
	[Organism_ID] [int] NOT NULL,
	[Cached_RowVersion] [binary](8) NOT NULL,
	[Last_Affected] [datetime] NOT NULL,
 CONSTRAINT [PK_T_DMS_Organism_DB_Info] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_DMS_Organism_DB_Info_FileName] ******/
CREATE NONCLUSTERED INDEX [IX_T_DMS_Organism_DB_Info_FileName] ON [dbo].[T_DMS_Organism_DB_Info]
(
	[FileName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_DMS_Organism_DB_Info] ADD  CONSTRAINT [DF_T_DMS_Organism_DB_Info_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
