/****** Object:  Table [dbo].[b137_MapLinkHGVS] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[b137_MapLinkHGVS](
	[snp_type] [char](2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[snp_id] [int] NULL,
	[gi] [int] NULL,
	[accession_how_cd] [int] NOT NULL,
	[offset] [int] NULL,
	[asn_to] [int] NULL,
	[lf_ngbr] [int] NULL,
	[rf_ngbr] [int] NULL,
	[lc_ngbr] [int] NULL,
	[rc_ngbr] [int] NULL,
	[loc_type] [tinyint] NULL,
	[build_id] [int] NULL,
	[process_time] [smalldatetime] NULL,
	[process_status] [int] NOT NULL,
	[orientation] [tinyint] NULL,
	[allele] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[aln_quality] [real] NULL,
	[num_mism] [int] NULL,
	[num_del] [int] NULL,
	[num_ins] [int] NULL,
	[tier] [tinyint] NULL,
	[ctg_gi] [int] NULL,
	[ctg_from] [int] NULL,
	[ctg_to] [int] NULL,
	[ctg_orient] [tinyint] NULL
) ON [PRIMARY]

GO
