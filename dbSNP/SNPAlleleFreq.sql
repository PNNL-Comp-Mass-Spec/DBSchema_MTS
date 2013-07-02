/****** Object:  Table [dbo].[SNPAlleleFreq] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SNPAlleleFreq](
	[snp_id] [int] NOT NULL,
	[allele_id] [int] NOT NULL,
	[chr_cnt] [float] NULL,
	[freq] [float] NULL,
	[last_updated_time] [datetime] NOT NULL,
 CONSTRAINT [PK_SNPAlleleFreq] PRIMARY KEY CLUSTERED 
(
	[snp_id] ASC,
	[allele_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
