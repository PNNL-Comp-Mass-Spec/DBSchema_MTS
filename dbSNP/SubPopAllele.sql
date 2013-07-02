/****** Object:  Table [dbo].[SubPopAllele] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SubPopAllele](
	[batch_id] [int] NOT NULL,
	[subsnp_id] [int] NOT NULL,
	[pop_id] [int] NOT NULL,
	[allele] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[other] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[freq] [real] NULL,
	[cnt_int] [int] NULL,
	[freq_min] [real] NULL,
	[freq_max] [real] NULL,
	[data_src] [varchar](6) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[type] [char](3) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[last_updated_time] [smalldatetime] NULL,
	[allele_flag] [tinyint] NULL,
	[cnt] [real] NULL,
	[allele_id] [int] NULL,
	[subpop_id] [int] NOT NULL
) ON [PRIMARY]

GO

/****** Object:  Index [iuc_SubPopAllele] ******/
CREATE CLUSTERED INDEX [iuc_SubPopAllele] ON [dbo].[SubPopAllele] 
(
	[batch_id] ASC,
	[subsnp_id] ASC,
	[pop_id] ASC,
	[allele] ASC,
	[other] ASC,
	[type] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_allele_id] ******/
CREATE NONCLUSTERED INDEX [i_allele_id] ON [dbo].[SubPopAllele] 
(
	[allele_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_last_updated_time] ******/
CREATE NONCLUSTERED INDEX [i_last_updated_time] ON [dbo].[SubPopAllele] 
(
	[last_updated_time] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_sp_ale] ******/
CREATE NONCLUSTERED INDEX [i_sp_ale] ON [dbo].[SubPopAllele] 
(
	[subpop_id] ASC,
	[type] ASC,
	[allele] ASC,
	[other] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_subpop_id] ******/
CREATE NONCLUSTERED INDEX [i_subpop_id] ON [dbo].[SubPopAllele] 
(
	[subpop_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_subsnp_id] ******/
CREATE NONCLUSTERED INDEX [i_subsnp_id] ON [dbo].[SubPopAllele] 
(
	[subsnp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_type] ******/
CREATE NONCLUSTERED INDEX [i_type] ON [dbo].[SubPopAllele] 
(
	[type] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [iSubPopAllele1] ******/
CREATE NONCLUSTERED INDEX [iSubPopAllele1] ON [dbo].[SubPopAllele] 
(
	[freq] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [iSubPopAllele2] ******/
CREATE NONCLUSTERED INDEX [iSubPopAllele2] ON [dbo].[SubPopAllele] 
(
	[freq_max] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [iSubPopAllele3] ******/
CREATE NONCLUSTERED INDEX [iSubPopAllele3] ON [dbo].[SubPopAllele] 
(
	[freq_min] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
