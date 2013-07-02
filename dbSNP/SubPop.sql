/****** Object:  Table [dbo].[SubPop] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SubPop](
	[batch_id] [int] NOT NULL,
	[subsnp_id] [int] NOT NULL,
	[pop_id] [int] NOT NULL,
	[type] [char](3) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[samplesize] [int] NOT NULL,
	[submitted_strand_code] [tinyint] NULL,
	[submitted_rs] [int] NULL,
	[allele_flag] [tinyint] NULL,
	[ambiguity_status] [tinyint] NULL,
	[sub_heterozygosity] [real] NULL,
	[est_heterozygosity] [real] NULL,
	[est_het_se_sq] [real] NULL,
	[last_updated_time] [smalldatetime] NOT NULL,
	[observed] [varchar](1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[sub_het_se_sq] [real] NULL,
	[subpop_id] [int] IDENTITY(1,1) NOT NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_pop_ss] ******/
CREATE NONCLUSTERED INDEX [i_pop_ss] ON [dbo].[SubPop] 
(
	[pop_id] ASC,
	[subsnp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_ss] ******/
CREATE NONCLUSTERED INDEX [i_ss] ON [dbo].[SubPop] 
(
	[subsnp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_subpop_id] ******/
CREATE NONCLUSTERED INDEX [i_subpop_id] ON [dbo].[SubPop] 
(
	[subpop_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
