/****** Object:  Table [dbo].[T_NET_Update_Task_Job_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_NET_Update_Task_Job_Map](
	[Task_ID] [int] NOT NULL,
	[Job] [int] NOT NULL,
 CONSTRAINT [PK_T_NET_Update_Task_Job_Map] PRIMARY KEY CLUSTERED 
(
	[Task_ID] ASC,
	[Job] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
GRANT INSERT ON [dbo].[T_NET_Update_Task_Job_Map] TO [pnl\svc-dms] AS [dbo]
GO
GRANT UPDATE ON [dbo].[T_NET_Update_Task_Job_Map] TO [pnl\svc-dms] AS [dbo]
GO
ALTER TABLE [dbo].[T_NET_Update_Task_Job_Map]  WITH CHECK ADD  CONSTRAINT [FK_T_NET_Update_Task_Job_Map_T_Analysis_Description] FOREIGN KEY([Job])
REFERENCES [dbo].[T_Analysis_Description] ([Job])
GO
ALTER TABLE [dbo].[T_NET_Update_Task_Job_Map] CHECK CONSTRAINT [FK_T_NET_Update_Task_Job_Map_T_Analysis_Description]
GO
ALTER TABLE [dbo].[T_NET_Update_Task_Job_Map]  WITH CHECK ADD  CONSTRAINT [FK_T_NET_Update_Task_Job_Map_T_NET_Update_Task] FOREIGN KEY([Task_ID])
REFERENCES [dbo].[T_NET_Update_Task] ([Task_ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[T_NET_Update_Task_Job_Map] CHECK CONSTRAINT [FK_T_NET_Update_Task_Job_Map_T_NET_Update_Task]
GO
