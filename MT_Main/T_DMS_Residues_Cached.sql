/****** Object:  Table [dbo].[T_DMS_Residues_Cached] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_DMS_Residues_Cached](
	[Residue_ID] [int] NOT NULL,
	[Residue_Symbol] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Description] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Average_Mass] [float] NOT NULL,
	[Monoisotopic_Mass] [float] NOT NULL,
	[Num_C] [smallint] NOT NULL,
	[Num_H] [smallint] NOT NULL,
	[Num_N] [smallint] NOT NULL,
	[Num_O] [smallint] NOT NULL,
	[Num_S] [smallint] NOT NULL,
	[Empirical_Formula] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Last_Affected] [datetime] NULL,
 CONSTRAINT [PK_T_DMS_Residues_Cached] PRIMARY KEY NONCLUSTERED 
(
	[Residue_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_DMS_Residues_Cached_Residue_Symbol] ******/
CREATE CLUSTERED INDEX [IX_T_DMS_Residues_Cached_Residue_Symbol] ON [dbo].[T_DMS_Residues_Cached]
(
	[Residue_Symbol] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_DMS_Residues_Cached] ADD  CONSTRAINT [DF_T_DMS_Residues_Cached_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
