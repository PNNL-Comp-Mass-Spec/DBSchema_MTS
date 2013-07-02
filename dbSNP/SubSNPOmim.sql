/****** Object:  Table [dbo].[SubSNPOmim] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SubSNPOmim](
	[subsnp_id] [int] NOT NULL,
	[omim_id] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[allele_variant_id] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[update_time] [smalldatetime] NULL,
	[mutObsCount] [int] NULL
) ON [PRIMARY]

GO
