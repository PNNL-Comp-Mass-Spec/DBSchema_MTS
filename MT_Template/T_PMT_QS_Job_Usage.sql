/****** Object:  Table [dbo].[T_PMT_QS_Job_Usage] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_PMT_QS_Job_Usage](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[Filter_Set_Info_ID] [int] NOT NULL,
	[Job] [int] NOT NULL,
	[Entered] [datetime] NOT NULL,
 CONSTRAINT [PK_T_PMT_QS_Job_Usage] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_PMT_QS_Job_Usage_Filter_Set_Info_ID] ******/
CREATE NONCLUSTERED INDEX [IX_T_PMT_QS_Job_Usage_Filter_Set_Info_ID] ON [dbo].[T_PMT_QS_Job_Usage] 
(
	[Filter_Set_Info_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_PMT_QS_Job_Usage_Job] ******/
CREATE NONCLUSTERED INDEX [IX_T_PMT_QS_Job_Usage_Job] ON [dbo].[T_PMT_QS_Job_Usage] 
(
	[Job] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_PMT_QS_Job_Usage]  WITH CHECK ADD  CONSTRAINT [FK_T_PMT_QS_Job_Usage_T_PMT_QS_Job_Usage_Filter_Info] FOREIGN KEY([Filter_Set_Info_ID])
REFERENCES [T_PMT_QS_Job_Usage_Filter_Info] ([Filter_Set_Info_ID])
GO
ALTER TABLE [dbo].[T_PMT_QS_Job_Usage] CHECK CONSTRAINT [FK_T_PMT_QS_Job_Usage_T_PMT_QS_Job_Usage_Filter_Info]
GO
ALTER TABLE [dbo].[T_PMT_QS_Job_Usage] ADD  CONSTRAINT [DF_T_PMT_QS_Job_Usage_Entered]  DEFAULT (getdate()) FOR [Entered]
GO
