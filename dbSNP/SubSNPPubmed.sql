/****** Object:  Table [dbo].[SubSNPPubmed] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SubSNPPubmed](
	[subsnp_id] [int] NOT NULL,
	[line_num] [int] NOT NULL,
	[pubmed_id] [int] NOT NULL,
	[updated_time] [smalldatetime] NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_pmid] ******/
CREATE NONCLUSTERED INDEX [i_pmid] ON [dbo].[SubSNPPubmed] 
(
	[pubmed_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
