/****** Object:  Table [dbo].[PerfStatsHistory] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PerfStatsHistory](
	[PerfStatsHistoryID] [int] IDENTITY(1,1) NOT NULL,
	[BufferCacheHitRatio] [numeric](38, 13) NULL,
	[PageLifeExpectency] [bigint] NULL,
	[BatchRequestsPerSecond] [bigint] NULL,
	[CompilationsPerSecond] [bigint] NULL,
	[ReCompilationsPerSecond] [bigint] NULL,
	[UserConnections] [bigint] NULL,
	[LockWaitsPerSecond] [bigint] NULL,
	[PageSplitsPerSecond] [bigint] NULL,
	[ProcessesBlocked] [bigint] NULL,
	[CheckpointPagesPerSecond] [bigint] NULL,
	[StatDate] [datetime] NOT NULL,
 CONSTRAINT [PK_PerfStatsHistory] PRIMARY KEY CLUSTERED 
(
	[PerfStatsHistoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[PerfStatsHistory] ADD  CONSTRAINT [DF_PerfStatsHistory_StatDate]  DEFAULT (getdate()) FOR [StatDate]
GO
