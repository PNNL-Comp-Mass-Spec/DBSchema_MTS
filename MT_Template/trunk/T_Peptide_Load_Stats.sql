/****** Object:  Table [dbo].[T_Peptide_Load_Stats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peptide_Load_Stats](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[Entry_Date] [datetime] NOT NULL CONSTRAINT [DF_T_Peptide_Load_Stats_Entry_Date]  DEFAULT (getdate()),
	[Jobs] [int] NULL,
	[Peptides_Unfiltered] [int] NULL,
	[PMTs_Unfiltered] [int] NULL,
	[Peptides_Filtered] [int] NULL,
	[PMTs_Filtered] [int] NULL,
	[Discriminant_Score_Minimum] [real] NULL,
	[Peptide_Prophet_Minimum] [real] NULL,
 CONSTRAINT [PK_T_Peptide_Load_Stats] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Peptide_Load_Stats_Discriminant_Score_Minimum] ******/
CREATE NONCLUSTERED INDEX [IX_T_Peptide_Load_Stats_Discriminant_Score_Minimum] ON [dbo].[T_Peptide_Load_Stats] 
(
	[Discriminant_Score_Minimum] ASC
) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Peptide_Load_Stats_Entry_Date] ******/
CREATE NONCLUSTERED INDEX [IX_T_Peptide_Load_Stats_Entry_Date] ON [dbo].[T_Peptide_Load_Stats] 
(
	[Entry_Date] ASC
) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Peptide_Load_Stats_Peptide_Prophet_Minimum] ******/
CREATE NONCLUSTERED INDEX [IX_T_Peptide_Load_Stats_Peptide_Prophet_Minimum] ON [dbo].[T_Peptide_Load_Stats] 
(
	[Peptide_Prophet_Minimum] ASC
) ON [PRIMARY]
GO
