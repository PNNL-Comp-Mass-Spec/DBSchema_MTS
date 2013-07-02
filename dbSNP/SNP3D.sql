/****** Object:  Table [dbo].[SNP3D] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SNP3D](
	[snp_id] [int] NOT NULL,
	[protein_acc] [char](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[master_gi] [int] NOT NULL,
	[neighbor_gi] [int] NOT NULL,
	[aa_position] [int] NOT NULL,
	[var_res] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[contig_res] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[neighbor_res] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[neighbor_pos] [int] NOT NULL,
	[var_color] [int] NOT NULL,
	[var_label] [int] NOT NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_rs] ******/
CREATE NONCLUSTERED INDEX [i_rs] ON [dbo].[SNP3D] 
(
	[snp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
