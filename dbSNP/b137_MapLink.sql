/****** Object:  Table [dbo].[b137_MapLink] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[b137_MapLink](
	[snp_type] [varchar](2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
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
	[build_id] [int] NOT NULL,
	[process_time] [smalldatetime] NULL,
	[process_status] [int] NOT NULL,
	[orientation] [int] NULL,
	[allele] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[aln_quality] [int] NOT NULL,
	[num_mism] [int] NULL,
	[num_del] [int] NULL,
	[num_ins] [int] NULL,
	[tier] [int] NULL,
	[ctg_gi] [int] NULL,
	[ctg_from] [int] NULL,
	[ctg_to] [int] NULL,
	[ctg_orient] [int] NULL,
	[source] [varchar](4) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_rs_gi_pos] ******/
CREATE CLUSTERED INDEX [i_rs_gi_pos] ON [dbo].[b137_MapLink] 
(
	[snp_id] ASC,
	[gi] ASC,
	[offset] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_src] ******/
CREATE NONCLUSTERED INDEX [i_src] ON [dbo].[b137_MapLink] 
(
	[source] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
