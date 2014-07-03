/****** Object:  Table [dbo].[T_QueryStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_QueryStats](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[interval_start] [smalldatetime] NOT NULL,
	[interval_end] [smalldatetime] NOT NULL,
	[sql_handle] [varbinary](64) NOT NULL,
	[plan_handle] [varbinary](64) NOT NULL,
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
	[last_execution_time] [smalldatetime] NOT NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_QueryStats_intervalend_sqlhandle_statementstartoffset_planhandle_U_C] ******/
CREATE UNIQUE CLUSTERED INDEX [IX_T_QueryStats_intervalend_sqlhandle_statementstartoffset_planhandle_U_C] ON [dbo].[T_QueryStats]
(
	[interval_end] ASC,
	[sql_handle] ASC,
	[statement_start_offset] ASC,
	[plan_handle] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
