/****** Object:  Table [dbo].[T_Process_Step_Control] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Process_Step_Control](
	[Processing_Step_Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Execution_State] [int] NOT NULL CONSTRAINT [DF_T_Process_Step_Control_Execution_State]  DEFAULT (0),
	[Last_Query_Date] [datetime] NULL,
	[Last_Query_Description] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Last_Query_Update_Count] [int] NOT NULL,
	[Pause_Location] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_Process_Step_Control] PRIMARY KEY CLUSTERED 
(
	[Processing_Step_Name] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Process_Step_Control]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Process_Step_Control_T_Process_Step_Control_States] FOREIGN KEY([Execution_State])
REFERENCES [T_Process_Step_Control_States] ([Execution_State])
GO
ALTER TABLE [dbo].[T_Process_Step_Control] CHECK CONSTRAINT [FK_T_Process_Step_Control_T_Process_Step_Control_States]
GO
