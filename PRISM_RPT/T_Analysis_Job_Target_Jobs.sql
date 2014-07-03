/****** Object:  Table [dbo].[T_Analysis_Job_Target_Jobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Analysis_Job_Target_Jobs](
	[Job_ID] [int] NOT NULL,
	[DMS_Job] [int] NOT NULL,
 CONSTRAINT [T_Analysis_Job_Target_Jobs_PK] PRIMARY KEY CLUSTERED 
(
	[Job_ID] ASC,
	[DMS_Job] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Index [IX_T_Analysis_Job_Target_Jobs] ******/
CREATE NONCLUSTERED INDEX [IX_T_Analysis_Job_Target_Jobs] ON [dbo].[T_Analysis_Job_Target_Jobs]
(
	[DMS_Job] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Analysis_Job_Target_Jobs]  WITH CHECK ADD  CONSTRAINT [FK_T_Analysis_Job_Target_Jobs_T_Analysis_Job] FOREIGN KEY([Job_ID])
REFERENCES [dbo].[T_Analysis_Job] ([Job_ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[T_Analysis_Job_Target_Jobs] CHECK CONSTRAINT [FK_T_Analysis_Job_Target_Jobs_T_Analysis_Job]
GO
