/****** Object:  Table [dbo].[b137_Remapped] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[b137_Remapped](
	[snp_type] [char](2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[snp_id] [int] NULL,
	[src_gi] [int] NOT NULL,
	[src_from] [int] NOT NULL,
	[src_to] [int] NOT NULL,
	[src_l_ngbr] [int] NOT NULL,
	[src_r_ngbr] [int] NOT NULL,
	[src_orientation] [tinyint] NULL,
	[src_aln_quality] [real] NULL,
	[tgt_gi] [int] NULL,
	[tgt_from] [int] NULL,
	[tgt_to] [int] NULL,
	[tgt_l_ngbr] [int] NULL,
	[tgt_r_ngbr] [int] NULL,
	[tgt_loc_type] [tinyint] NOT NULL,
	[tgt_orientation] [tinyint] NULL,
	[tgt_allele] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[tgt_aln_quality] [real] NULL,
	[last_updated_time] [smalldatetime] NOT NULL,
	[comment] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]

GO
