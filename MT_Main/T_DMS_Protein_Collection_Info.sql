/****** Object:  Table [dbo].[T_DMS_Protein_Collection_Info] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_DMS_Protein_Collection_Info](
	[Protein_Collection_ID] [int] NOT NULL,
	[Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Description] [varchar](900) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Collection_State] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Collection_Type] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Protein_Count] [int] NULL,
	[Residue_Count] [int] NULL,
	[Annotation_Naming_Authority] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Annotation_Type] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Organism_ID_First] [int] NULL,
	[Organism_ID_Last] [int] NULL,
	[Created] [datetime] NULL,
	[Last_Modified] [datetime] NULL,
	[Authentication_Hash] [varchar](8) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Last_Affected] [datetime] NOT NULL,
 CONSTRAINT [PK_T_DMS_Protein_Collection_Info] PRIMARY KEY CLUSTERED 
(
	[Protein_Collection_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_DMS_Protein_Collection_Info_Name] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_DMS_Protein_Collection_Info_Name] ON [dbo].[T_DMS_Protein_Collection_Info] 
(
	[Name] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_DMS_Protein_Collection_Info] ADD  CONSTRAINT [DF_T_DMS_Protein_Collection_Info_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
