/****** Object:  Table [dbo].[T_Peptide_Filter_Flags] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peptide_Filter_Flags](
	[Filter_ID] [int] NOT NULL,
	[Peptide_ID] [int] NOT NULL,
 CONSTRAINT [PK_T_Peptide_Filter_Flags] PRIMARY KEY NONCLUSTERED 
(
	[Filter_ID] ASC,
	[Peptide_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Index [IX_T_Peptide_Filter_Flags_Peptide_ID] ******/
CREATE CLUSTERED INDEX [IX_T_Peptide_Filter_Flags_Peptide_ID] ON [dbo].[T_Peptide_Filter_Flags]
(
	[Peptide_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Peptide_Filter_Flags]  WITH CHECK ADD  CONSTRAINT [FK_T_Peptide_Filter_Flags_T_Peptides] FOREIGN KEY([Peptide_ID])
REFERENCES [dbo].[T_Peptides] ([Peptide_ID])
GO
ALTER TABLE [dbo].[T_Peptide_Filter_Flags] CHECK CONSTRAINT [FK_T_Peptide_Filter_Flags_T_Peptides]
GO
