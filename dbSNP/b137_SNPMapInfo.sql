/****** Object:  Table [dbo].[b137_SNPMapInfo] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[b137_SNPMapInfo](
	[snp_type] [char](2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[snp_id] [int] NOT NULL,
	[chr_cnt] [int] NOT NULL,
	[contig_cnt] [int] NOT NULL,
	[loc_cnt] [int] NOT NULL,
	[weight] [int] NOT NULL,
	[hap_cnt] [int] NULL,
	[placed_cnt] [int] NOT NULL,
	[unlocalized_cnt] [int] NOT NULL,
	[unplaced_cnt] [int] NOT NULL,
	[aligned_cnt] [int] NOT NULL,
	[md5] [char](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[asm_acc] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[asm_version] [smallint] NULL,
	[assembly] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_rs_asm] ******/
CREATE CLUSTERED INDEX [i_rs_asm] ON [dbo].[b137_SNPMapInfo] 
(
	[snp_id] ASC,
	[asm_acc] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
