/****** Object:  Table [dbo].[SNPAlleleFreq_TGP] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SNPAlleleFreq_TGP](
	[snp_id] [int] NOT NULL,
	[allele_id] [int] NOT NULL,
	[freq] [float] NOT NULL,
	[count] [int] NOT NULL,
	[is_minor_allele] [bit] NOT NULL,
 CONSTRAINT [PK_SNPAlleleFreq_TGP] PRIMARY KEY CLUSTERED 
(
	[snp_id] ASC,
	[allele_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
