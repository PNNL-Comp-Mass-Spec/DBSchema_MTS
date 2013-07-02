/****** Object:  Table [dbo].[b137_SNPContigLoc] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[b137_SNPContigLoc](
	[snp_type] [char](2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[snp_id] [int] NOT NULL,
	[ctg_id] [int] NOT NULL,
	[asn_from] [int] NOT NULL,
	[asn_to] [int] NOT NULL,
	[lf_ngbr] [int] NULL,
	[rf_ngbr] [int] NULL,
	[lc_ngbr] [int] NOT NULL,
	[rc_ngbr] [int] NOT NULL,
	[loc_type] [tinyint] NOT NULL,
	[phys_pos_from] [int] NULL,
	[snp_bld_id] [int] NOT NULL,
	[last_updated_time] [smalldatetime] NOT NULL,
	[process_status] [tinyint] NOT NULL,
	[orientation] [tinyint] NULL,
	[allele] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[loc_sts_uid] [int] NULL,
	[aln_quality] [real] NULL,
	[num_mism] [int] NULL,
	[num_del] [int] NULL,
	[num_ins] [int] NULL,
	[tier] [tinyint] NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_pos] ******/
CREATE NONCLUSTERED INDEX [i_pos] ON [dbo].[b137_SNPContigLoc] 
(
	[ctg_id] ASC,
	[asn_from] ASC,
	[snp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_rs] ******/
CREATE NONCLUSTERED INDEX [i_rs] ON [dbo].[b137_SNPContigLoc] 
(
	[snp_id] ASC,
	[ctg_id] ASC,
	[asn_from] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
