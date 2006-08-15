/****** Object:  Table [dbo].[T_Proteins] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Proteins](
	[Ref_ID] [int] IDENTITY(100,1) NOT NULL,
	[Reference] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Description] [varchar](7500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Protein_Sequence] [text] COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Protein_Residue_Count] [int] NULL,
	[Monoisotopic_Mass] [float] NULL,
	[Protein_DB_ID] [int] NULL,
	[External_Reference_ID] [int] NULL,
	[External_Protein_ID] [int] NULL,
	[Protein_Collection_ID] [int] NULL,
	[Last_Affected] [datetime] NOT NULL CONSTRAINT [DF_T_Proteins_Last_Affected]  DEFAULT (getdate()),
 CONSTRAINT [PK_T_Proteins] PRIMARY KEY CLUSTERED 
(
	[Ref_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Proteins_External_Reference_ID] ******/
CREATE NONCLUSTERED INDEX [IX_T_Proteins_External_Reference_ID] ON [dbo].[T_Proteins] 
(
	[External_Reference_ID] ASC
) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Proteins_Protein_Collection_ID] ******/
CREATE NONCLUSTERED INDEX [IX_T_Proteins_Protein_Collection_ID] ON [dbo].[T_Proteins] 
(
	[Protein_Collection_ID] ASC
) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Proteins_Reference] ******/
CREATE NONCLUSTERED INDEX [IX_T_Proteins_Reference] ON [dbo].[T_Proteins] 
(
	[Reference] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
GO
