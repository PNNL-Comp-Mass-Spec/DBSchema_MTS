/****** Object:  Table [dbo].[CPUStatsHistory] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CPUStatsHistory](
	[CPUStatsHistoryID] [int] IDENTITY(1,1) NOT NULL,
	[SQLProcessPercent] [int] NULL,
	[SystemIdleProcessPercent] [int] NULL,
	[OtherProcessPerecnt] [int] NULL,
	[DateStamp] [datetime] NULL,
 CONSTRAINT [PK_CPUStatsHistory] PRIMARY KEY CLUSTERED 
(
	[CPUStatsHistoryID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
