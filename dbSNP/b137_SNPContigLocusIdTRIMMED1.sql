/****** Object:  Table [dbo].[b137_SNPContigLocusIdTRIMMED1] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[b137_SNPContigLocusIdTRIMMED1](
	[snp_id] [int] NULL,
	[protein_acc] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[fxn_class] [int] NULL,
	[residue] [varchar](1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[aa_position] [int] NULL
) ON [PRIMARY]

GO
