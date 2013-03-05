/****** Object:  Table [dbo].[T_Score_MSAlign] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Score_MSAlign](
	[Peptide_ID] [int] NOT NULL,
	[Prsm_ID] [int] NULL,
	[PrecursorMZ] [real] NULL,
	[DelM] [real] NULL,
	[Unexpected_Mod_Count] [smallint] NULL,
	[Peak_Count] [smallint] NULL,
	[Matched_Peak_Count] [smallint] NULL,
	[Matched_Fragment_Ion_Count] [smallint] NULL,
	[PValue] [real] NULL,
	[EValue] [real] NULL,
	[FDR] [real] NULL,
	[Normalized_Score] [real] NULL,
 CONSTRAINT [PK_T_Score_MSAlign] PRIMARY KEY CLUSTERED 
(
	[Peptide_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Score_MSAlign]  WITH CHECK ADD  CONSTRAINT [FK_T_Score_MSAlign_T_Peptides] FOREIGN KEY([Peptide_ID])
REFERENCES [T_Peptides] ([Peptide_ID])
GO
ALTER TABLE [dbo].[T_Score_MSAlign] CHECK CONSTRAINT [FK_T_Score_MSAlign_T_Peptides]
GO
