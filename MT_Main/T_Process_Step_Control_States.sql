/****** Object:  Table [dbo].[T_Process_Step_Control_States] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Process_Step_Control_States](
	[Execution_State] [int] NOT NULL,
	[Execution_State_Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_Process_Step_Control_States] PRIMARY KEY CLUSTERED 
(
	[Execution_State] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
