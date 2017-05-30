/****** Object:  Table [dbo].[T_QueryStats_Expensive] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_QueryStats_Expensive](
	[Entry_ID] [int] NOT NULL,
	[Min_Time_Threshold] [int] NOT NULL,
	[Total_Time_Threshold] [int] NOT NULL,
	[Min_Time_Threshold_Exceeded] [tinyint] NOT NULL,
	[Total_Time_Threshold_Exceeded] [tinyint] NOT NULL,
	[sql_handle] [varbinary](64) NOT NULL,
	[statement_start_offset] [int] NOT NULL,
	[statement_end_offset] [int] NOT NULL,
	[execution_count] [int] NOT NULL,
	[total_elapsed_time_ms] [int] NOT NULL,
	[min_elapsed_time_ms] [int] NOT NULL,
	[max_elapsed_time_ms] [int] NOT NULL,
	[total_worker_time_ms] [int] NOT NULL,
	[min_worker_time_ms] [int] NOT NULL,
	[max_worker_time_ms] [int] NOT NULL,
	[total_logical_reads] [int] NOT NULL,
	[min_logical_reads] [int] NOT NULL,
	[max_logical_reads] [int] NOT NULL,
	[total_physical_reads] [int] NOT NULL,
	[min_physical_reads] [int] NOT NULL,
	[max_physical_reads] [int] NOT NULL,
	[total_logical_writes] [int] NOT NULL,
	[min_logical_writes] [int] NOT NULL,
	[max_logical_writes] [int] NOT NULL,
	[creation_time] [smalldatetime] NOT NULL,
	[last_execution_time] [smalldatetime] NOT NULL,
	[Entered] [datetime] NOT NULL,
 CONSTRAINT [PK_T_QueryStats_Expensive] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
