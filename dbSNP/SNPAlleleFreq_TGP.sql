/****** Object:  Table [dbo].[SNPAlleleFreq_TGP] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SNPAlleleFreq_TGP](
	[snp_id] [int] NULL,
	[allele_id] [int] NOT NULL,
	[freq] [float] NOT NULL,
	[count] [int] NOT NULL,
	[is_minor_allele] [bit] NOT NULL
) ON [PRIMARY]

GO
