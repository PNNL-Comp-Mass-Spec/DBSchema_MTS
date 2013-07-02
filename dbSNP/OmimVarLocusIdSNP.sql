/****** Object:  Table [dbo].[OmimVarLocusIdSNP] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[OmimVarLocusIdSNP](
	[omim_id] [int] NOT NULL,
	[locus_id] [int] NULL,
	[omimvar_id] [char](4) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[locus_symbol] [char](10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[var1] [char](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[aa_position] [int] NULL,
	[var2] [char](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[var_class] [int] NOT NULL,
	[snp_id] [int] NOT NULL
) ON [PRIMARY]

GO
