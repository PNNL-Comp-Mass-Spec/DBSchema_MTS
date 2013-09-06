/****** Object:  Table [dbo].[SNPAlleleFreq_TGP_TRIMMED_FreqPt01Plus] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SNPAlleleFreq_TGP_TRIMMED_FreqPt01Plus](
	[snp_id] [int] NOT NULL,
	[allele_id] [int] NOT NULL,
	[freq] [float] NULL,
	[is_minor_allele] [bit] NOT NULL
) ON [PRIMARY]

GO
