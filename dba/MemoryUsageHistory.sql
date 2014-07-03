/****** Object:  Table [dbo].[MemoryUsageHistory] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MemoryUsageHistory](
	[MemoryUsageHistoryID] [int] IDENTITY(1,1) NOT NULL,
	[DateStamp] [datetime] NOT NULL,
	[SystemPhysicalMemoryMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[SystemVirtualMemoryMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DBUsageMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DBMemoryRequiredMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[BufferCacheHitRatio] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[BufferPageLifeExpectancy] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[BufferPoolCommitMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[BufferPoolCommitTgtMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[BufferPoolTotalPagesMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[BufferPoolDataPagesMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[BufferPoolFreePagesMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[BufferPoolReservedPagesMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[BufferPoolStolenPagesMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[BufferPoolPlanCachePagesMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DynamicMemConnectionsMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DynamicMemLocksMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DynamicMemSQLCacheMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DynamicMemQueryOptimizeMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DynamicMemHashSortIndexMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[CursorUsageMB] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [pk_MemoryUsageHistory] PRIMARY KEY CLUSTERED 
(
	[MemoryUsageHistoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[MemoryUsageHistory] ADD  CONSTRAINT [DF_MemoryUsageHistory_DateStamp]  DEFAULT (getdate()) FOR [DateStamp]
GO
