/****** Object:  Table [dbo].[FreqSummaryBySsPop] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[FreqSummaryBySsPop](
	[subsnp_id] [int] NOT NULL,
	[pop_id] [int] NOT NULL,
	[source] [varchar](1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[chr_cnt] [float] NULL,
	[ind_cnt] [float] NULL,
	[non_founder_ind_cnt] [int] NOT NULL,
	[chisq] [float] NULL,
	[df] [int] NULL,
	[hwp] [float] NOT NULL,
	[het] [int] NULL,
	[het_se] [int] NULL,
	[last_updated_time] [datetime] NOT NULL
) ON [PRIMARY]

GO

/****** Object:  Index [t_hwp_chisq] ******/
CREATE CLUSTERED INDEX [t_hwp_chisq] ON [dbo].[FreqSummaryBySsPop] 
(
	[subsnp_id] ASC,
	[pop_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
