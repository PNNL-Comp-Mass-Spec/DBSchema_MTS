/****** Object:  Table [dbo].[SubSNPSeqPos] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SubSNPSeqPos](
	[subsnp_id] [int] NOT NULL,
	[contig_acc] [varchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[contig_pos] [int] NOT NULL,
	[chr] [varchar](2) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[upstream_len] [int] NOT NULL,
	[downstream_len] [int] NOT NULL,
	[last_update_time] [smalldatetime] NOT NULL,
	[mrna_acc] [varchar](24) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]

GO
