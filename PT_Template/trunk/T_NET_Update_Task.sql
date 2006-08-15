/****** Object:  Table [dbo].[T_NET_Update_Task] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_NET_Update_Task](
	[Task_ID] [int] IDENTITY(1,1) NOT NULL,
	[Processing_State] [tinyint] NOT NULL,
	[Task_Created] [datetime] NULL CONSTRAINT [DF_T_NET_Update_Task_Task_Created]  DEFAULT (getdate()),
	[Task_Start] [datetime] NULL,
	[Task_Finish] [datetime] NULL,
	[Task_AssignedProcessorName] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Output_Folder_Path] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Out_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Results_Folder_Path] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Results_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PredictNETs_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_NET_Update_Task] PRIMARY KEY CLUSTERED 
(
	[Task_ID] ASC
) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_NET_Update_Task]  WITH CHECK ADD  CONSTRAINT [FK_T_NET_Update_Task_T_NET_Update_Task_State_Name] FOREIGN KEY([Processing_State])
REFERENCES [T_NET_Update_Task_State_Name] ([Processing_State])
GO
ALTER TABLE [dbo].[T_NET_Update_Task] CHECK CONSTRAINT [FK_T_NET_Update_Task_T_NET_Update_Task_State_Name]
GO
