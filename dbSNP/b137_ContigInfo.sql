/****** Object:  Table [dbo].[b137_ContigInfo] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[b137_ContigInfo](
	[ctg_id] [int] NOT NULL,
	[tax_id] [int] NOT NULL,
	[contig_acc] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[contig_ver] [smallint] NOT NULL,
	[contig_name] [varchar](63) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[contig_chr] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[contig_start] [int] NULL,
	[contig_end] [int] NULL,
	[orient] [tinyint] NULL,
	[contig_gi] [int] NOT NULL,
	[group_term] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[group_label] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[contig_label] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[primary_fl] [tinyint] NOT NULL,
	[genbank_gi] [int] NULL,
	[genbank_acc] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[genbank_ver] [smallint] NULL,
	[build_id] [int] NOT NULL,
	[build_ver] [int] NOT NULL,
	[last_updated_time] [datetime] NOT NULL,
	[placement_status] [tinyint] NOT NULL,
	[asm_acc] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[asm_version] [smallint] NULL,
	[chr_gi] [int] NULL,
	[par_fl] [tinyint] NULL,
	[top_level_fl] [tinyint] NOT NULL,
	[gen_rgn] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_asm_chr_ctg] ******/
CREATE NONCLUSTERED INDEX [i_asm_chr_ctg] ON [dbo].[b137_ContigInfo] 
(
	[asm_acc] ASC,
	[asm_version] ASC,
	[chr_gi] ASC,
	[contig_start] ASC,
	[contig_end] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
