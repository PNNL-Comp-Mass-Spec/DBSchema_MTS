/****** Object:  Table [dbo].[T_QueryStatsLast] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_QueryStatsLast](
	[sql_handle] [varbinary](64) NOT NULL,
	[plan_handle] [varbinary](64) NOT NULL,
	[statement_start_offset] [int] NOT NULL,
	[statement_end_offset] [int] NOT NULL,
	[objtype] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[execution_count] [bigint] NOT NULL,
	[total_elapsed_time_ms] [bigint] NOT NULL,
	[min_elapsed_time_ms] [bigint] NOT NULL,
	[max_elapsed_time_ms] [bigint] NOT NULL,
	[total_worker_time_ms] [bigint] NOT NULL,
	[min_worker_time_ms] [bigint] NOT NULL,
	[max_worker_time_ms] [bigint] NOT NULL,
	[total_logical_reads] [bigint] NOT NULL,
	[min_logical_reads] [bigint] NOT NULL,
	[max_logical_reads] [bigint] NOT NULL,
	[total_physical_reads] [bigint] NOT NULL,
	[min_physical_reads] [bigint] NOT NULL,
	[max_physical_reads] [bigint] NOT NULL,
	[total_logical_writes] [bigint] NOT NULL,
	[min_logical_writes] [bigint] NOT NULL,
	[max_logical_writes] [bigint] NOT NULL,
	[creation_time] [datetime] NOT NULL,
	[last_execution_time] [datetime] NOT NULL,
	[DateAdded] [datetime] NOT NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_QueryStatsLast_sqlhandle_planhandle_statementstartoffset_U_C] ******/
CREATE UNIQUE CLUSTERED INDEX [IX_T_QueryStatsLast_sqlhandle_planhandle_statementstartoffset_U_C] ON [dbo].[T_QueryStatsLast]
(
	[sql_handle] ASC,
	[plan_handle] ASC,
	[statement_start_offset] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
