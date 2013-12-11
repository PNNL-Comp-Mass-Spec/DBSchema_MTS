/****** Object:  Table [dbo].[T_MyEMSL_Cache_Task] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MyEMSL_Cache_Task](
	[Task_ID] [int] IDENTITY(1000,1) NOT NULL,
	[Processor] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Task_State] [tinyint] NOT NULL,
	[Task_Start] [datetime] NULL,
	[Task_Complete] [datetime] NULL,
	[Completion_Code] [int] NULL,
	[Completion_Message] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_MyEMSL_Cache_Task] PRIMARY KEY CLUSTERED 
(
	[Task_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_MyEMSL_Cache_Task]  WITH CHECK ADD  CONSTRAINT [FK_T_MyEMSL_Cache_Task_T_MyEMSL_Cache_State] FOREIGN KEY([Task_State])
REFERENCES [T_MyEMSL_Cache_State] ([State])
GO
ALTER TABLE [dbo].[T_MyEMSL_Cache_Task] CHECK CONSTRAINT [FK_T_MyEMSL_Cache_Task_T_MyEMSL_Cache_State]
GO
