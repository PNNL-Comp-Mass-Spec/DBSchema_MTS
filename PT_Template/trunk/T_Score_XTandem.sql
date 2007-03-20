/****** Object:  Table [dbo].[T_Score_XTandem] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Score_XTandem](
	[Peptide_ID] [int] NOT NULL,
	[Hyperscore] [real] NULL,
	[Log_EValue] [real] NULL,
	[DeltaCn2] [real] NULL,
	[Y_Score] [real] NULL,
	[Y_Ions] [tinyint] NULL,
	[B_Score] [real] NULL,
	[B_Ions] [tinyint] NULL,
	[DelM] [real] NULL,
	[Intensity] [real] NULL,
	[Normalized_Score] [real] NULL,
 CONSTRAINT [PK_T_Score_XTandem] PRIMARY KEY CLUSTERED 
(
	[Peptide_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Score_XTandem]  WITH CHECK ADD  CONSTRAINT [FK_T_Score_XTandem_T_Peptides] FOREIGN KEY([Peptide_ID])
REFERENCES [T_Peptides] ([Peptide_ID])
GO
ALTER TABLE [dbo].[T_Score_XTandem] CHECK CONSTRAINT [FK_T_Score_XTandem_T_Peptides]
GO
