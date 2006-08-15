/****** Object:  Table [dbo].[T_NET_Update_Task_State_Name] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_NET_Update_Task_State_Name](
	[Processing_State] [tinyint] NOT NULL,
	[Processing_State_Name] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_NET_Update_Task_State_Name] PRIMARY KEY CLUSTERED 
(
	[Processing_State] ASC
) ON [PRIMARY]
) ON [PRIMARY]

GO
