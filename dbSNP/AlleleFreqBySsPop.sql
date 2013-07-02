/****** Object:  Table [dbo].[AlleleFreqBySsPop] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AlleleFreqBySsPop](
	[subsnp_id] [int] NOT NULL,
	[pop_id] [int] NOT NULL,
	[allele_id] [int] NOT NULL,
	[source] [varchar](2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[cnt] [real] NULL,
	[freq] [real] NULL,
	[last_updated_time] [datetime] NOT NULL
) ON [PRIMARY]

GO
