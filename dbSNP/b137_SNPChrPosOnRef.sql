/****** Object:  Table [dbo].[b137_SNPChrPosOnRef] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[b137_SNPChrPosOnRef](
	[snp_id] [int] NOT NULL,
	[chr] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[pos] [int] NULL,
	[orien] [int] NULL,
	[neighbor_snp_list] [int] NULL,
	[isPAR] [varchar](1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_rs] ******/
CREATE CLUSTERED INDEX [i_rs] ON [dbo].[b137_SNPChrPosOnRef] 
(
	[snp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
